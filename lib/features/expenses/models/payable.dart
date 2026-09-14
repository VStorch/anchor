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
  /// Paying the month on screen happens now; settling another month is
  /// dated on its due day, where the money belonged.
  DateTime suggestedPaidAt(DateTime now) =>
      month == Month.fromDate(now) ? now : stampFor(dueDate, now: now);
}
