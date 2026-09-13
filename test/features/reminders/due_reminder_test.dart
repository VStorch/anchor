import 'package:anchor/core/utils/month.dart';
import 'package:anchor/features/expenses/models/expense.dart';
import 'package:anchor/features/expenses/models/expense_occurrence.dart';
import 'package:anchor/features/expenses/models/expense_payment.dart';
import 'package:anchor/features/expenses/models/expense_type.dart';
import 'package:anchor/features/reminders/models/due_reminder.dart';
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
    final reminders = DueReminder.plan([
      bill('Luz', dueDay: 12, amount: 143.2),
    ], now: now);

    expect(reminders.single.at, DateTime(2026, 9, 12, 9));
    expect(reminders.single.title, 'Luz vence hoje');
    expect(reminders.single.body, contains('143,20'));
  });

  test('junta as contas do mesmo dia num aviso só', () {
    final reminders = DueReminder.plan([
      bill('Luz', dueDay: 15, amount: 100),
      bill('Internet', dueDay: 15, amount: 120),
      bill('Aluguel', dueDay: 15, amount: 1200),
      bill('Mercado', dueDay: 20),
    ], now: now);

    expect(reminders, hasLength(2));
    expect(reminders.first.title, '3 contas vencem hoje');
    expect(reminders.first.body, startsWith('Luz, Internet e Aluguel'));
    expect(reminders.first.body, contains('1.420,00'));
    expect(reminders.first.id, isNot(reminders.last.id));
  });

  test('não avisa o que está pago nem o que já passou', () {
    final reminders = DueReminder.plan([
      bill('Paga', dueDay: 15, paid: 100),
      bill('Ontem', dueDay: 9),
      bill('Hoje cedo', dueDay: 10),
    ], now: DateTime(2026, 9, 10, 9, 30));

    expect(reminders, isEmpty);
  });

  test('a parcial avisa só o que falta', () {
    final reminders = DueReminder.plan([
      bill('Mercado', dueDay: 15, amount: 600, paid: 400),
    ], now: now);

    expect(reminders.single.body, contains('200,00'));
  });
}
