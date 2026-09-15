import 'package:anchor/core/utils/month.dart';
import 'package:anchor/features/expenses/models/expense.dart';
import 'package:anchor/features/expenses/models/expense_occurrence.dart';
import 'package:anchor/features/expenses/models/expense_payment.dart';
import 'package:anchor/features/expenses/models/expense_type.dart';
import 'package:anchor/features/reminders/models/due_reminder.dart';
import 'package:anchor/features/reminders/models/reminder_lead.dart';
import 'package:flutter_test/flutter_test.dart';

const Month september = Month(2026, 9);

ExpenseOccurrence bill(
  String name, {
  required int dueDay,
  double amount = 100,
  double paid = 0,
}) {
  final expense = Expense(
    id: name.hashCode,
    name: name,
    type: ExpenseType.recurring,
    amount: amount,
    dueDay: dueDay,
    startMonth: september,
    createdAt: DateTime(2026, 9),
  );
  return expense
      .occurrenceIn(september)!
      .withLedger(
        payments: [
          if (paid > 0)
            ExpensePayment(
              expenseId: expense.id!,
              walletId: 1,
              month: september,
              amount: paid,
              paidAt: DateTime(2026, 9, 2),
            ),
        ],
      );
}

void main() {
  final now = DateTime(2026, 9, 10, 8);

  test('avisa às 9h do vencimento o que ainda falta pagar', () {
    final reminders = DueReminder.plan(
      [bill('Luz', dueDay: 12, amount: 143.2)],
      now: now,
      lead: ReminderLead.sameDay,
    );

    expect(reminders.single.at, DateTime(2026, 9, 12, 9));
    expect(reminders.single.title, 'Luz vence hoje');
    expect(reminders.single.body, contains('143,20'));
  });

  test('junta as contas do mesmo dia num aviso só', () {
    final reminders = DueReminder.plan(
      [
        bill('Luz', dueDay: 15, amount: 100),
        bill('Internet', dueDay: 15, amount: 120),
        bill('Aluguel', dueDay: 15, amount: 1200),
        bill('Mercado', dueDay: 20),
      ],
      now: now,
      lead: ReminderLead.sameDay,
    );

    expect(reminders, hasLength(2));
    expect(reminders.first.title, '3 contas vencem hoje');
    expect(reminders.first.body, startsWith('Luz, Internet e Aluguel'));
    expect(reminders.first.body, contains('1.420,00'));
    expect(reminders.first.id, isNot(reminders.last.id));
  });

  test('não avisa o que está pago nem o que já passou', () {
    final reminders = DueReminder.plan(
      [
        bill('Paga', dueDay: 15, paid: 100),
        bill('Ontem', dueDay: 9),
        bill('Hoje cedo', dueDay: 10),
      ],
      now: DateTime(2026, 9, 10, 9, 30),
      lead: ReminderLead.sameDay,
    );

    expect(reminders, isEmpty);
  });

  test('a parcial avisa só o que falta', () {
    final reminders = DueReminder.plan([
      bill('Mercado', dueDay: 15, amount: 600, paid: 400),
    ], now: now);

    expect(reminders, hasLength(2));
    expect(reminders.every((r) => r.body.contains('200,00')), isTrue);
  });

  test('um dia antes avisa às 9h da véspera que vence amanhã', () {
    final reminders = DueReminder.plan(
      [bill('Luz', dueDay: 12, amount: 143.2), bill('Água', dueDay: 12)],
      now: now,
      lead: ReminderLead.dayBefore,
    );

    expect(reminders.single.at, DateTime(2026, 9, 11, 9));
    expect(reminders.single.title, '2 contas vencem amanhã');
    expect(reminders.single.body, startsWith('Luz e Água'));
  });

  test('os dois avisam na véspera e no dia, com ids diferentes', () {
    final reminders = DueReminder.plan([bill('Luz', dueDay: 12)], now: now);

    expect(reminders.map((r) => r.at), [
      DateTime(2026, 9, 11, 9),
      DateTime(2026, 9, 12, 9),
    ]);
    expect(reminders.map((r) => r.title), [
      'Luz vence amanhã',
      'Luz vence hoje',
    ]);
    expect(reminders.first.id, isNot(reminders.last.id));
  });

  test('a conta de amanhã e a de hoje no mesmo 13/09 9h não dividem o id', () {
    final reminders = DueReminder.plan(
      [bill('Internet', dueDay: 14), bill('Luz', dueDay: 13)],
      now: DateTime(2026, 9, 12, 20),
      lead: ReminderLead.both,
    );
    final atThirteen = reminders
        .where((r) => r.at == DateTime(2026, 9, 13, 9))
        .toList();

    expect(
      atThirteen.map((r) => r.title),
      unorderedEquals(['Internet vence amanhã', 'Luz vence hoje']),
    );
    expect(reminders.map((r) => r.id).toSet(), hasLength(reminders.length));
    expect(DueReminder.idFor(DateTime(2026, 9, 14), 1), 202609141);
    expect(DueReminder.idFor(DateTime(9999, 12, 31), 1) < 1 << 31, isTrue);
  });

  test('a véspera que já passou fica de fora, o aviso do dia não', () {
    final reminders = DueReminder.plan([
      bill('Luz', dueDay: 11),
    ], now: DateTime(2026, 9, 10, 10));

    expect(reminders.single.title, 'Luz vence hoje');
  });

  test('a véspera do dia 1 cai no último dia do mês anterior', () {
    final october = Expense(
      id: 1,
      name: 'Aluguel',
      type: ExpenseType.recurring,
      amount: 1200,
      dueDay: 1,
      startMonth: september,
      createdAt: DateTime(2026, 9),
    ).occurrenceIn(september.next)!;

    final reminders = DueReminder.plan(
      [october],
      now: now,
      lead: ReminderLead.dayBefore,
    );

    expect(reminders.single.at, DateTime(2026, 9, 30, 9));
  });
}
