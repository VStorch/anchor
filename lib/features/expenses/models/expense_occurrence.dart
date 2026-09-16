import 'dart:math';

import '../../../core/utils/money.dart';
import '../../../core/utils/month.dart';
import 'due_state.dart';
import 'expense.dart';
import 'expense_payment.dart';
import 'expense_type.dart';
import 'payable.dart';

class ExpenseOccurrence implements Payable {
  const ExpenseOccurrence({
    required this.expense,
    required this.month,
    this.installmentNumber,
    this.monthAmount,
    this.payments = const <ExpensePayment>[],
    this.today,
  }) : offRule = false;

  /// A paid month the current rule no longer projects.
  const ExpenseOccurrence.offRule({
    required this.expense,
    required this.month,
    this.monthAmount,
    required this.payments,
    this.today,
  }) : installmentNumber = null,
       offRule = true;

  final Expense expense;
  @override
  final Month month;
  final int? installmentNumber;
  final double? monthAmount;
  final List<ExpensePayment> payments;
  final bool offRule;

  /// The day the month summary was built with; null reads the device clock.
  final DateTime? today;

  @override
  String get name => expense.name;

  /// Off the rule, the month owes nothing beyond what was paid: a month
  /// amount stored before the rule changed is kept but ignored.
  @override
  double get amount => offRule ? paidAmount : monthAmount ?? expense.amount;

  bool get hasCustomAmount => monthAmount != null;

  @override
  double get paidAmount =>
      payments.fold(0, (total, payment) => total + payment.amount);

  /// What actually left a wallet; money from outside settles the bill only.
  double get paidFromWallets => payments
      .where((payment) => !payment.settledOutside)
      .fold(0, (total, payment) => total + payment.amount);

  bool get hasOutsidePayments =>
      payments.any((payment) => payment.settledOutside);

  @override
  double get remaining =>
      offRule || isPaid ? 0 : roundCents(max(0, amount - paidAmount));

  @override
  bool get isPaid => coversAmount(paidAmount, amount);

  @override
  bool get isPartlyPaid => paidAmount > 0 && !isPaid;

  @override
  double get paidRatio => amount <= 0 ? 1 : (paidAmount / amount).clamp(0, 1);

  int? get plannedWalletId => expense.walletId;

  List<int> get paidWalletIds => payments
      .map((payment) => payment.walletId)
      .whereType<int>()
      .toSet()
      .toList();

  @override
  DateTime get dueDate => month.dayOf(expense.dueDay);

  @override
  bool get isOverdue => dueState == DueState.overdue;

  @override
  DueState get dueState {
    if (offRule) return DueState.offRule;
    if (isPaid) return DueState.paid;
    return dueStateOf(dueDate, today ?? DateTime.now());
  }

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
  }) => offRule
      ? ExpenseOccurrence.offRule(
          expense: expense,
          month: month,
          monthAmount: monthAmount,
          payments: payments,
          today: today,
        )
      : ExpenseOccurrence(
          expense: expense,
          month: month,
          installmentNumber: installmentNumber,
          monthAmount: monthAmount,
          payments: payments,
          today: today,
        );
}

extension OccurrenceTotals on Iterable<ExpenseOccurrence> {
  double get totalAmount =>
      roundCents(fold(0, (total, occurrence) => total + occurrence.amount));

  double get totalPaid =>
      roundCents(fold(0, (total, occurrence) => total + occurrence.paidAmount));

  double get totalPaidFromWallets => roundCents(
    fold(0, (total, occurrence) => total + occurrence.paidFromWallets),
  );

  /// Summed per occurrence, so an overpaid bill never hides one still open.
  double get totalRemaining =>
      roundCents(fold(0, (total, occurrence) => total + occurrence.remaining));

  double paidRatio({required double whenEmpty}) {
    final amount = totalAmount;
    if (amount <= 0) return whenEmpty;
    return ((amount - totalRemaining) / amount).clamp(0, 1);
  }
}
