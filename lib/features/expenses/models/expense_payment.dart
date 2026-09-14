import '../../../core/utils/month.dart';

/// Where the money of a payment came from: a wallet, or money the app does
/// not follow ("Outro dinheiro").
typedef PaymentOrigin = ({int? walletId, bool outside});

class ExpensePayment {
  const ExpensePayment({
    this.id,
    required this.expenseId,
    this.walletId,
    required this.month,
    required this.amount,
    required this.paidAt,
    this.settledOutside = false,
  }) : assert(settledOutside == (walletId == null));

  factory ExpensePayment.fromOrigin({
    int? id,
    required int expenseId,
    required PaymentOrigin origin,
    required Month month,
    required double amount,
    required DateTime paidAt,
  }) => ExpensePayment(
    id: id,
    expenseId: expenseId,
    walletId: origin.outside ? null : origin.walletId,
    month: month,
    amount: amount,
    paidAt: paidAt,
    settledOutside: origin.outside || origin.walletId == null,
  );

  factory ExpensePayment.fromMap(Map<String, Object?> map) => ExpensePayment(
    id: map['id'] as int?,
    expenseId: map['expense_id'] as int,
    walletId: map['wallet_id'] as int?,
    month: Month.fromKey(map['month_key'] as String),
    amount: (map['amount'] as num).toDouble(),
    paidAt: DateTime.parse(map['paid_at'] as String),
    settledOutside: map['settled_outside'] == 1,
  );

  final int? id;
  final int expenseId;
  final int? walletId;
  final Month month;
  final double amount;
  final DateTime paidAt;
  final bool settledOutside;

  PaymentOrigin get origin => (walletId: walletId, outside: settledOutside);

  Map<String, Object?> toMap() => <String, Object?>{
    if (id != null) 'id': id,
    'expense_id': expenseId,
    'wallet_id': walletId,
    'month_key': month.key,
    'amount': amount,
    'paid_at': paidAt.toIso8601String(),
    'settled_outside': settledOutside ? 1 : 0,
  };
}
