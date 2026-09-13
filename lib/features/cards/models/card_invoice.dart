import 'dart:math';

import '../../../core/utils/money.dart';
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
  final Month month;
  final List<ExpenseOccurrence> items;

  @override
  String get name => 'Fatura ${card.name}';

  @override
  DateTime get dueDate => card.dueDateIn(month);

  @override
  double get amount => items.fold(0, (total, item) => total + item.amount);

  @override
  double get paidAmount =>
      items.fold(0, (total, item) => total + item.paidAmount);

  @override
  double get remaining => max(0, amount - paidAmount);

  @override
  double get paidRatio => amount <= 0 ? 1 : (paidAmount / amount).clamp(0, 1);

  @override
  bool get isPaid => items.isNotEmpty && coversAmount(paidAmount, amount);

  @override
  bool get isPartlyPaid => paidAmount > 0 && !isPaid;

  @override
  bool get isOverdue => items.any((item) => item.isOverdue);

  List<ExpenseOccurrence> get unpaidItems =>
      items.where((item) => !item.isPaid).toList();
}
