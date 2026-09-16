import 'package:anchor/core/utils/month.dart';
import 'package:anchor/features/budget/models/month_summary.dart';
import 'package:anchor/features/cards/models/card_invoice.dart';
import 'package:anchor/features/cards/models/credit_card.dart';
import 'package:anchor/features/cards/models/invoice_status.dart';
import 'package:anchor/features/expenses/models/due_state.dart';
import 'package:anchor/features/expenses/models/expense.dart';
import 'package:anchor/features/expenses/models/expense_payment.dart';
import 'package:anchor/features/expenses/models/expense_type.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  const september = Month(2026, 9);
  const october = Month(2026, 10);

  setUpAll(() => initializeDateFormatting('pt_BR'));

  final nubank = CreditCard(
    id: 1,
    name: 'Nubank',
    closingDay: 3,
    dueDay: 10,
    walletId: 1,
    createdAt: DateTime(2026, 9),
  );

  Expense purchase({
    required int id,
    required DateTime? purchasedAt,
    Month? startMonth,
    double amount = 200,
  }) => Expense(
    id: id,
    name: 'Compra $id',
    type: ExpenseType.single,
    amount: amount,
    dueDay: 10,
    startMonth:
        startMonth ??
        nubank.invoiceMonthFor(purchasedAt ?? DateTime(2026, 9, 1)),
    walletId: 1,
    cardId: 1,
    purchasedAt: purchasedAt,
    createdAt: DateTime(2026, 9),
  );

  CardInvoice invoiceOf(
    Month month, {
    required DateTime today,
    List<Expense> expenses = const <Expense>[],
    List<ExpensePayment> payments = const <ExpensePayment>[],
  }) => MonthSummary.build(
    month: month,
    expenses: expenses,
    payments: payments,
    receipts: const [],
    cards: [nubank],
    today: today,
  ).invoiceOf(1)!;

  group('situação da fatura', () {
    final tennis = purchase(id: 1, purchasedAt: DateTime(2026, 9, 13));

    test('antes do fechamento está aberta', () {
      final invoice = invoiceOf(
        october,
        today: DateTime(2026, 9, 14),
        expenses: [tennis],
      );

      expect(invoice.status, InvoiceStatus.open);
      expect(invoice.statusLabel, 'Aberta · fecha 03/10');
    });

    test('no dia do fechamento ainda está aberta', () {
      expect(
        invoiceOf(
          october,
          today: DateTime(2026, 10, 3, 20),
          expenses: [tennis],
        ).status,
        InvoiceStatus.open,
      );
    });

    test('depois do fechamento está fechada até vencer', () {
      final invoice = invoiceOf(
        october,
        today: DateTime(2026, 10, 10, 23),
        expenses: [tennis],
      );

      expect(invoice.status, InvoiceStatus.closed);
      expect(invoice.statusLabel, 'Fechada · vence 10/10');
    });

    test('depois do vencimento sem pagamento está atrasada', () {
      final invoice = invoiceOf(
        october,
        today: DateTime(2026, 10, 11),
        expenses: [tennis],
      );

      expect(invoice.status, InvoiceStatus.overdue);
      expect(invoice.isOverdue, isTrue);
      expect(invoice.statusLabel, 'Atrasada');
    });

    test('paga continua paga mesmo depois do vencimento', () {
      final invoice = invoiceOf(
        october,
        today: DateTime(2026, 11, 20),
        expenses: [tennis],
        payments: [
          ExpensePayment(
            expenseId: 1,
            walletId: 1,
            month: october,
            amount: 200,
            paidAt: DateTime(2026, 10, 9),
          ),
        ],
      );

      expect(invoice.status, InvoiceStatus.paid);
      expect(invoice.statusLabel, 'Paga');
    });
  });

  test('a fatura sem compras não fecha nem vence', () {
    expect(
      invoiceOf(september, today: DateTime(2026, 9, 1)).statusLabel,
      'Sem compras · fecha 03/09',
    );
    expect(
      invoiceOf(september, today: DateTime(2026, 9, 14)).statusLabel,
      'Sem compras',
    );
  });

  test('a fatura diz quando vence, e paga não vence mais', () {
    final tennis = purchase(id: 1, purchasedAt: DateTime(2026, 9, 13));

    expect(
      invoiceOf(
        october,
        today: DateTime(2026, 10, 9),
        expenses: [tennis],
      ).dueState,
      DueState.tomorrow,
    );
    expect(
      invoiceOf(
        october,
        today: DateTime(2026, 10, 10, 8),
        expenses: [tennis],
      ).dueState,
      DueState.today,
    );
    expect(
      invoiceOf(
        october,
        today: DateTime(2026, 10, 11),
        expenses: [tennis],
      ).dueState,
      DueState.overdue,
    );
    expect(
      invoiceOf(
        october,
        today: DateTime(2026, 10, 11),
        expenses: [tennis],
        payments: [
          ExpensePayment(
            expenseId: 1,
            walletId: 1,
            month: october,
            amount: 200,
            paidAt: DateTime(2026, 10, 9),
          ),
        ],
      ).dueState,
      DueState.paid,
    );
    expect(
      invoiceOf(october, today: DateTime(2026, 10, 10)).dueState,
      DueState.upcoming,
    );
  });

  test('a compra de 13/09 não deixa a fatura de setembro atrasada', () {
    final today = DateTime(2026, 9, 14);
    final expenses = [purchase(id: 1, purchasedAt: DateTime(2026, 9, 13))];

    final septemberInvoice = invoiceOf(
      september,
      today: today,
      expenses: expenses,
    );
    final octoberInvoice = invoiceOf(october, today: today, expenses: expenses);

    expect(septemberInvoice.items, isEmpty);
    expect(septemberInvoice.isOverdue, isFalse);
    expect(octoberInvoice.items.single.expense.name, 'Compra 1');
    expect(octoberInvoice.dueDate, DateTime(2026, 10, 10));
    expect(octoberInvoice.isOverdue, isFalse);
  });

  test('lista as compras na ordem em que foram feitas', () {
    final invoice = invoiceOf(
      october,
      today: DateTime(2026, 9, 20),
      expenses: [
        purchase(id: 1, purchasedAt: DateTime(2026, 9, 18)),
        purchase(id: 2, purchasedAt: null, startMonth: october),
        purchase(id: 3, purchasedAt: DateTime(2026, 9, 5)),
      ],
    );

    expect(invoice.purchases.map((item) => item.expense.id), [2, 3, 1]);
  });
}
