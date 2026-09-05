import 'dart:math';

import '../../../core/utils/money.dart';
import '../../../core/utils/month.dart';
import 'expense.dart';
import 'expense_payment.dart';
import 'expense_type.dart';

class ExpenseOccurrence {
  const ExpenseOccurrence({
    required this.expense,
    required this.month,
    this.installmentNumber,
    this.monthAmount,
    this.payments = const <ExpensePayment>[],
  });

  final Expense expense;
  final Month month;
  final int? installmentNumber;
  final double? monthAmount;
  final List<ExpensePayment> payments;

  double get amount => monthAmount ?? expense.amount;

  bool get hasCustomAmount => monthAmount != null;

  double get paidAmount =>
      payments.fold(0, (total, payment) => total + payment.amount);

  double get remaining => max(0, amount - paidAmount);

  bool get isPaid => coversAmount(paidAmount, amount);

  bool get isPartlyPaid => paidAmount > 0 && !isPaid;

  double get paidRatio => amount <= 0 ? 1 : (paidAmount / amount).clamp(0, 1);

  int? get plannedWalletId => expense.walletId;

  List<int> get paidWalletIds => payments
      .map((payment) => payment.walletId)
      .whereType<int>()
      .toSet()
      .toList();

  DateTime get dueDate => month.dayOf(expense.dueDay);

  bool get isOverdue => !isPaid && dueDate.isBefore(_today);

  String? get installmentLabel =>
      expense.type == ExpenseType.installment && installmentNumber != null
      ? '$installmentNumber de ${expense.totalInstallments}'
      : null;

  bool get isLastInstallment =>
      installmentNumber != null &&
      installmentNumber == expense.totalInstallments;

  ExpenseOccurrence withLedger({
    double? monthAmount,
    List<ExpensePayment> payments = const <ExpensePayment>[],
  }) => ExpenseOccurrence(
    expense: expense,
    month: month,
    installmentNumber: installmentNumber,
    monthAmount: monthAmount,
    payments: payments,
  );

  static DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }
}
