import 'package:intl/intl.dart';

import '../../../core/utils/month.dart';
import '../../expenses/models/due_state.dart';
import '../../expenses/models/expense_occurrence.dart';
import '../../expenses/models/payable.dart';
import 'credit_card.dart';
import 'invoice_status.dart';

class CardInvoice implements Payable {
  const CardInvoice({
    required this.card,
    required this.month,
    required this.items,
    required this.today,
  });

  final CreditCard card;
  @override
  final Month month;
  final List<ExpenseOccurrence> items;
  final DateTime today;

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
  bool get isOverdue => dueState == DueState.overdue;

  @override
  DueState get dueState {
    if (isPaid) return DueState.paid;
    if (items.isEmpty) return DueState.upcoming;
    return dueStateOf(dueDate, today);
  }

  DateTime get closingDate => card.closingDateOf(month);

  InvoiceStatus get status {
    if (isPaid) return InvoiceStatus.paid;
    if (isOverdue) return InvoiceStatus.overdue;
    return _startOf(today).isAfter(closingDate)
        ? InvoiceStatus.closed
        : InvoiceStatus.open;
  }

  String get statusLabel => switch (status) {
    InvoiceStatus.open =>
      '${status.label} · fecha ${_dayAndMonth(closingDate)}',
    InvoiceStatus.closed => '${status.label} · vence ${_dayAndMonth(dueDate)}',
    InvoiceStatus.overdue || InvoiceStatus.paid => status.label,
  };

  /// The purchases in the order they were made; one saved before the purchase
  /// day was recorded goes first, as the oldest.
  List<ExpenseOccurrence> get purchases => [...items]
    ..sort((a, b) {
      final left = a.expense.purchasedAt;
      final right = b.expense.purchasedAt;
      if (left == null) return right == null ? 0 : -1;
      if (right == null) return 1;
      return left.compareTo(right);
    });

  List<ExpenseOccurrence> get unpaidItems =>
      items.where((item) => !item.isPaid).toList();

  static DateTime _startOf(DateTime day) =>
      DateTime(day.year, day.month, day.day);

  static String _dayAndMonth(DateTime date) =>
      DateFormat('dd/MM', 'pt_BR').format(date);

  /// The payments that pay the invoice off, adding up to exactly [remaining].
  List<(ExpenseOccurrence, double)> get settlement => [
    for (final item in unpaidItems)
      if (item.remaining > 0) (item, item.remaining),
  ];
}
