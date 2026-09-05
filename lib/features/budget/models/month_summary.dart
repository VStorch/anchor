import '../../../core/utils/month.dart';
import '../../expenses/models/expense.dart';
import '../../expenses/models/expense_month.dart';
import '../../expenses/models/expense_occurrence.dart';
import '../../expenses/models/expense_payment.dart';
import '../../wallets/models/outflow.dart';
import '../../wallets/models/receipt.dart';
import '../../wallets/models/wallet.dart';

class MonthSummary {
  const MonthSummary({
    required this.month,
    required this.occurrences,
    required this.receipts,
    required this.outflows,
    required this.wallets,
  });

  factory MonthSummary.build({
    required Month month,
    required List<Expense> expenses,
    required List<ExpensePayment> payments,
    required List<Receipt> receipts,
    required List<Wallet> wallets,
    List<ExpenseMonth> monthAmounts = const <ExpenseMonth>[],
    List<Outflow> outflows = const <Outflow>[],
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
      final occurrence = expense.occurrenceIn(month);
      if (occurrence == null) continue;
      occurrences.add(
        occurrence.withLedger(
          monthAmount: amountByExpense[expense.id],
          payments: paymentsByExpense[expense.id] ?? const <ExpensePayment>[],
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
      wallets: wallets,
    );
  }

  static MonthSummary empty(Month month) => MonthSummary(
    month: month,
    occurrences: const <ExpenseOccurrence>[],
    receipts: const <Receipt>[],
    outflows: const <Outflow>[],
    wallets: const <Wallet>[],
  );

  final Month month;
  final List<ExpenseOccurrence> occurrences;
  final List<Receipt> receipts;
  final List<Outflow> outflows;
  final List<Wallet> wallets;

  bool get isEmpty =>
      occurrences.isEmpty && receipts.isEmpty && outflows.isEmpty;

  List<ExpenseOccurrence> get pendingOccurrences =>
      occurrences.where((occurrence) => !occurrence.isPaid).toList();

  List<ExpenseOccurrence> get paidOccurrences =>
      occurrences.where((occurrence) => occurrence.isPaid).toList();

  List<ExpenseOccurrence> get overdueOccurrences =>
      occurrences.where((occurrence) => occurrence.isOverdue).toList();

  ExpenseOccurrence? occurrenceOf(int expenseId) {
    for (final occurrence in occurrences) {
      if (occurrence.expense.id == expenseId) return occurrence;
    }
    return null;
  }

  List<Receipt> get unconfirmedReceipts => receipts
      .where((receipt) => receipt.isPredicted && !receipt.isAdjustment)
      .toList();

  double get totalExpenses =>
      occurrences.fold(0, (total, occurrence) => total + occurrence.amount);

  double get totalPaid =>
      occurrences.fold(0, (total, occurrence) => total + occurrence.paidAmount);

  double get totalPending => totalExpenses - totalPaid;

  double get totalOutflows =>
      outflows.fold(0, (total, outflow) => total + outflow.amount);

  double get totalSpent => totalPaid + totalOutflows;

  double get totalReceived => receipts
      .where((receipt) => !receipt.isAdjustment)
      .fold(0, (total, receipt) => total + receipt.amount);

  double get expectedIncome =>
      wallets.fold(0, (total, wallet) => total + wallet.monthlyIncome);

  double get balance => totalReceived - totalSpent;

  double get projectedBalance => expectedIncome - totalExpenses;

  double get paidRatio =>
      totalExpenses <= 0 ? 0 : (totalPaid / totalExpenses).clamp(0, 1);
}
