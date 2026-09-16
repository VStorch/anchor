import '../../../core/utils/moment.dart';
import '../../../core/utils/month.dart';
import 'due_state.dart';

/// One line of "what I owe this month": a loose expense occurrence, or a
/// card invoice that bundles several of them into a single bill.
abstract interface class Payable {
  String get name;
  Month get month;
  DateTime get dueDate;
  double get amount;
  double get paidAmount;
  double get remaining;
  double get paidRatio;
  bool get isPaid;
  bool get isPartlyPaid;
  bool get isOverdue;

  /// Read against the `today` the summary was built with, never `DateTime.now()`
  /// inside a view.
  DueState get dueState;
}

/// The date half of [Payable.dueState], shared by the occurrence and the
/// invoice: everything that is neither paid nor off the rule.
DueState dueStateOf(DateTime dueDate, DateTime today) {
  final due = DateTime(dueDate.year, dueDate.month, dueDate.day);
  final start = DateTime(today.year, today.month, today.day);
  if (due.isBefore(start)) return DueState.overdue;
  if (due.isAtSameMomentAs(start)) return DueState.today;
  if (due.isAtSameMomentAs(DateTime(start.year, start.month, start.day + 1))) {
    return DueState.tomorrow;
  }
  return DueState.upcoming;
}

extension PayableDates on Payable {
  /// A payment is never dated ahead: settling a past month is dated on its
  /// due day, where the money belonged; the current or a later month is now.
  DateTime suggestedPaidAt(DateTime now) =>
      month < Month.fromDate(now) ? stampFor(dueDate, now: now) : now;

  /// Dated inside a balance informed at [checkedAt], so paying moves nothing.
  DateTime paidBefore(DateTime checkedAt, {DateTime? now}) {
    final dueStamp = stampFor(dueDate, now: now);
    final justBefore = checkedAt.subtract(const Duration(seconds: 1));
    return dueStamp.isBefore(justBefore) ? dueStamp : justBefore;
  }
}
