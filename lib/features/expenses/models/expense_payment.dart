import '../../../core/utils/month.dart';

class ExpensePayment {
  const ExpensePayment({
    this.id,
    required this.expenseId,
    this.walletId,
    required this.month,
    required this.amount,
    required this.paidAt,
  });

  factory ExpensePayment.fromMap(Map<String, Object?> map) => ExpensePayment(
    id: map['id'] as int?,
    expenseId: map['expense_id'] as int,
    walletId: map['wallet_id'] as int?,
    month: Month.fromKey(map['month_key'] as String),
    amount: (map['amount'] as num).toDouble(),
    paidAt: DateTime.parse(map['paid_at'] as String),
  );

  final int? id;
  final int expenseId;
  final int? walletId;
  final Month month;
  final double amount;
  final DateTime paidAt;

  Map<String, Object?> toMap() => <String, Object?>{
    if (id != null) 'id': id,
    'expense_id': expenseId,
    'wallet_id': walletId,
    'month_key': month.key,
    'amount': amount,
    'paid_at': paidAt.toIso8601String(),
  };
}
