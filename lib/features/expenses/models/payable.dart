import '../../../core/utils/moment.dart';
import '../../../core/utils/month.dart';

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
