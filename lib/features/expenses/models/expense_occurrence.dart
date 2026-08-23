import '../../../core/utils/month.dart';
import 'expense.dart';
import 'expense_payment.dart';
import 'expense_type.dart';

class ExpenseOccurrence {
  const ExpenseOccurrence({
    required this.expense,
    required this.month,
    this.installmentNumber,
    this.payment,
  });

  final Expense expense;
  final Month month;
  final int? installmentNumber;
  final ExpensePayment? payment;

  bool get isPaid => payment != null;

  double get amount => payment?.amount ?? expense.amount;

  int? get walletId => payment?.walletId ?? expense.walletId;

  DateTime get dueDate => month.dayOf(expense.dueDay);

  bool get isOverdue => !isPaid && dueDate.isBefore(_today);

  String? get installmentLabel =>
      expense.type == ExpenseType.installment && installmentNumber != null
      ? '$installmentNumber de ${expense.totalInstallments}'
      : null;

  bool get isLastInstallment =>
      installmentNumber != null &&
      installmentNumber == expense.totalInstallments;

  ExpenseOccurrence withPayment(ExpensePayment? payment) => ExpenseOccurrence(
    expense: expense,
    month: month,
    installmentNumber: installmentNumber,
    payment: payment,
  );

  static DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }
}
