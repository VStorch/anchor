import '../../../core/utils/month.dart';
import '../../expenses/models/expense_occurrence.dart';
import '../../expenses/models/payable.dart';
import 'credit_card.dart';

class CardInvoice implements Payable {
  const CardInvoice({
    required this.card,
    required this.month,
    required this.items,
  });

  final CreditCard card;
  @override
  final Month month;
  final List<ExpenseOccurrence> items;

  @override
  String get name => 'Fatura ${card.name}';

  @override
  DateTime get dueDate => card.dueDateIn(month);

  @override
  double get amount => items.totalAmount;

  @override
  double get paidAmount => items.totalPaid;

  /// What each purchase still owes: money paid over one purchase does not
  /// settle another, the same rule the month totals follow.
  @override
  double get remaining => items.totalRemaining;

  @override
  double get paidRatio => items.paidRatio(whenEmpty: 1);

  @override
  bool get isPaid => items.isNotEmpty && unpaidItems.isEmpty;

  @override
  bool get isPartlyPaid => paidAmount > 0 && !isPaid;

  @override
  bool get isOverdue => items.any((item) => item.isOverdue);

  List<ExpenseOccurrence> get unpaidItems =>
      items.where((item) => !item.isPaid).toList();

  /// The payments that pay the invoice off, adding up to exactly [remaining].
  List<(ExpenseOccurrence, double)> get settlement => [
    for (final item in unpaidItems)
      if (item.remaining > 0) (item, item.remaining),
  ];
}
