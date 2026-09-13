/// One line of "what I owe this month": a loose expense occurrence, or a
/// card invoice that bundles several of them into a single bill.
abstract interface class Payable {
  String get name;
  DateTime get dueDate;
  double get amount;
  double get paidAmount;
  double get remaining;
  double get paidRatio;
  bool get isPaid;
  bool get isPartlyPaid;
  bool get isOverdue;
}
