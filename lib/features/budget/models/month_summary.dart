import '../../../core/utils/money.dart';
import '../../../core/utils/month.dart';
import '../../cards/models/card_invoice.dart';
import '../../cards/models/credit_card.dart';
import '../../expenses/models/expense.dart';
import '../../expenses/models/expense_month.dart';
import '../../expenses/models/expense_occurrence.dart';
import '../../expenses/models/expense_payment.dart';
import '../../expenses/models/payable.dart';
import '../../wallets/models/outflow.dart';
import '../../wallets/models/receipt.dart';

class MonthSummary {
  const MonthSummary({
    required this.month,
    required this.occurrences,
    required this.receipts,
    required this.outflows,
    this.cards = const <CreditCard>[],
  });

  factory MonthSummary.build({
    required Month month,
    required List<Expense> expenses,
    required List<ExpensePayment> payments,
    required List<Receipt> receipts,
    List<ExpenseMonth> monthAmounts = const <ExpenseMonth>[],
    List<Outflow> outflows = const <Outflow>[],
    List<CreditCard> cards = const <CreditCard>[],
  }) {
    final paymentsByExpense = <int, List<ExpensePayment>>{};
    for (final payment in payments) {
      if (payment.month != month) continue;
      paymentsByExpense
          .putIfAbsent(payment.expenseId, () => <ExpensePayment>[])
          .add(payment);
    }

    final amountByExpense = <int, double>{
      for (final entry in monthAmounts)
        if (entry.month == month) entry.expenseId: entry.amount,
    };

    final occurrences = <ExpenseOccurrence>[];
    for (final expense in expenses) {
      final monthAmount = amountByExpense[expense.id];
      final expensePayments =
          paymentsByExpense[expense.id] ?? const <ExpensePayment>[];

      final occurrence = expense.occurrenceIn(month);
      if (occurrence == null) {
        if (expensePayments.isNotEmpty) {
          occurrences.add(
            ExpenseOccurrence.offRule(
              expense: expense,
              month: month,
              monthAmount: monthAmount,
              payments: expensePayments,
            ),
          );
        }
        continue;
      }

      final isUntouchedProjection =
          monthAmount == null && expensePayments.isEmpty;
      if (isUntouchedProjection && expense.projectsBackIntoPast(month)) {
        continue;
      }

      occurrences.add(
        occurrence.withLedger(
          monthAmount: monthAmount,
          payments: expensePayments,
        ),
      );
    }
    occurrences.sort((a, b) => a.dueDate.compareTo(b.dueDate));

    return MonthSummary(
      month: month,
      occurrences: occurrences,
      receipts: receipts
          .where((receipt) => receipt.month == month && receipt.counts)
          .toList(),
      outflows: outflows.where((outflow) => outflow.month == month).toList(),
      cards: cards,
    );
  }

  static MonthSummary empty(Month month) => MonthSummary(
    month: month,
    occurrences: const <ExpenseOccurrence>[],
    receipts: const <Receipt>[],
    outflows: const <Outflow>[],
  );

  final Month month;
  final List<ExpenseOccurrence> occurrences;
  final List<Receipt> receipts;
  final List<Outflow> outflows;
  final List<CreditCard> cards;

  bool get isEmpty =>
      occurrences.isEmpty && receipts.isEmpty && outflows.isEmpty;

  List<CardInvoice> get invoices => [
    for (final card in cards)
      CardInvoice(
        card: card,
        month: month,
        items: occurrences
            .where((occurrence) => occurrence.expense.cardId == card.id)
            .toList(),
      ),
  ];

  CardInvoice? invoiceOf(int cardId) {
    for (final invoice in invoices) {
      if (invoice.card.id == cardId) return invoice;
    }
    return null;
  }

  /// What the month owes, with each card's purchases folded into its invoice.
  List<Payable> get payables {
    final cardIds = cards.map((card) => card.id).toSet();
    return <Payable>[
      ...occurrences.where(
        (occurrence) => !cardIds.contains(occurrence.expense.cardId),
      ),
      ...invoices.where((invoice) => invoice.items.isNotEmpty),
    ]..sort((a, b) => a.dueDate.compareTo(b.dueDate));
  }

  List<Payable> get pendingPayables =>
      payables.where((payable) => !payable.isPaid).toList();

  List<Payable> get paidPayables =>
      payables.where((payable) => payable.isPaid).toList();

  List<ExpenseOccurrence> get pendingOccurrences =>
      occurrences.where((occurrence) => !occurrence.isPaid).toList();

  List<ExpenseOccurrence> get paidOccurrences =>
      occurrences.where((occurrence) => occurrence.isPaid).toList();

  List<Payable> get overduePayables =>
      payables.where((payable) => payable.isOverdue).toList();

  ExpenseOccurrence? occurrenceOf(int expenseId) {
    for (final occurrence in occurrences) {
      if (occurrence.expense.id == expenseId) return occurrence;
    }
    return null;
  }

  List<Receipt> get unconfirmedReceipts =>
      receipts.where((receipt) => receipt.isPredicted).toList();

  double get totalExpenses => occurrences.totalAmount;

  double get totalPaid => occurrences.totalPaid;

  double get totalPending => occurrences.totalRemaining;

  double get totalOutflows =>
      roundCents(outflows.fold(0, (total, outflow) => total + outflow.amount));

  double get totalSpent => roundCents(totalPaid + totalOutflows);

  double get totalReceived => roundCents(
    receipts
        .where((receipt) => receipt.isConfirmed)
        .fold(0, (total, receipt) => total + receipt.amount),
  );

  double get balance => roundCents(totalReceived - totalSpent);

  double get paidRatio => occurrences.paidRatio(whenEmpty: 0);
}
