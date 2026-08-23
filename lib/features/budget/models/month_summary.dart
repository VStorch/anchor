import '../../../core/utils/month.dart';
import '../../expenses/models/expense.dart';
import '../../expenses/models/expense_occurrence.dart';
import '../../expenses/models/expense_payment.dart';
import '../../wallets/models/receipt.dart';
import '../../wallets/models/wallet.dart';

class MonthSummary {
  const MonthSummary({
    required this.month,
    required this.occurrences,
    required this.receipts,
    required this.wallets,
  });

  factory MonthSummary.build({
    required Month month,
    required List<Expense> expenses,
    required List<ExpensePayment> payments,
    required List<Receipt> receipts,
    required List<Wallet> wallets,
  }) {
    final paymentsByExpense = <int, ExpensePayment>{
      for (final payment in payments)
        if (payment.month == month) payment.expenseId: payment,
    };

    final occurrences = <ExpenseOccurrence>[];
    for (final expense in expenses) {
      final occurrence = expense.occurrenceIn(month);
      if (occurrence == null) continue;
      occurrences.add(occurrence.withPayment(paymentsByExpense[expense.id]));
    }
    occurrences.sort((a, b) => a.dueDate.compareTo(b.dueDate));

    return MonthSummary(
      month: month,
      occurrences: occurrences,
      receipts: receipts.where((receipt) => receipt.month == month).toList(),
      wallets: wallets,
    );
  }

  static MonthSummary empty(Month month) => MonthSummary(
    month: month,
    occurrences: const <ExpenseOccurrence>[],
    receipts: const <Receipt>[],
    wallets: const <Wallet>[],
  );

  final Month month;
  final List<ExpenseOccurrence> occurrences;
  final List<Receipt> receipts;
  final List<Wallet> wallets;

  bool get isEmpty => occurrences.isEmpty && receipts.isEmpty;

  List<ExpenseOccurrence> get pendingOccurrences =>
      occurrences.where((occurrence) => !occurrence.isPaid).toList();

  List<ExpenseOccurrence> get paidOccurrences =>
      occurrences.where((occurrence) => occurrence.isPaid).toList();

  List<ExpenseOccurrence> get overdueOccurrences =>
      occurrences.where((occurrence) => occurrence.isOverdue).toList();

  double get totalExpenses =>
      occurrences.fold(0, (total, occurrence) => total + occurrence.amount);

  double get totalPaid =>
      paidOccurrences.fold(0, (total, occurrence) => total + occurrence.amount);

  double get totalPending => totalExpenses - totalPaid;

  double get totalReceived =>
      receipts.fold(0, (total, receipt) => total + receipt.amount);

  double get expectedIncome =>
      wallets.fold(0, (total, wallet) => total + wallet.monthlyIncome);

  double get balance => totalReceived - totalPaid;

  double get projectedBalance => expectedIncome - totalExpenses;

  double get paidRatio =>
      totalExpenses <= 0 ? 0 : (totalPaid / totalExpenses).clamp(0, 1);
}
