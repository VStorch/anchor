import '../../../core/utils/month.dart';

class ExpenseMonth {
  const ExpenseMonth({
    this.id,
    required this.expenseId,
    required this.month,
    required this.amount,
  });

  factory ExpenseMonth.fromMap(Map<String, Object?> map) => ExpenseMonth(
    id: map['id'] as int?,
    expenseId: map['expense_id'] as int,
    month: Month.fromKey(map['month_key'] as String),
    amount: (map['amount'] as num).toDouble(),
  );

  final int? id;
  final int expenseId;
  final Month month;
  final double amount;

  Map<String, Object?> toMap() => <String, Object?>{
    if (id != null) 'id': id,
    'expense_id': expenseId,
    'month_key': month.key,
    'amount': amount,
  };
}
