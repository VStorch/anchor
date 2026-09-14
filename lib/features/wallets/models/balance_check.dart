class BalanceCheck {
  const BalanceCheck({
    this.id,
    required this.walletId,
    required this.amount,
    required this.checkedAt,
  });

  factory BalanceCheck.fromMap(Map<String, Object?> map) => BalanceCheck(
    id: map['id'] as int?,
    walletId: map['wallet_id'] as int,
    amount: (map['amount'] as num).toDouble(),
    checkedAt: DateTime.parse(map['checked_at'] as String),
  );

  final int? id;
  final int walletId;
  final double amount;
  final DateTime checkedAt;

  Map<String, Object?> toMap() => <String, Object?>{
    if (id != null) 'id': id,
    'wallet_id': walletId,
    'amount': amount,
    'checked_at': checkedAt.toIso8601String(),
  };

  BalanceCheck copyWith({double? amount, DateTime? checkedAt}) => BalanceCheck(
    id: id,
    walletId: walletId,
    amount: amount ?? this.amount,
    checkedAt: checkedAt ?? this.checkedAt,
  );
}
