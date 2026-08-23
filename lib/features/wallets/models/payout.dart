class Payout {
  const Payout({
    this.id,
    required this.walletId,
    required this.label,
    required this.amount,
    required this.dayOfMonth,
  });

  factory Payout.fromMap(Map<String, Object?> map) => Payout(
    id: map['id'] as int?,
    walletId: map['wallet_id'] as int,
    label: map['label'] as String,
    amount: (map['amount'] as num).toDouble(),
    dayOfMonth: map['day_of_month'] as int,
  );

  final int? id;
  final int walletId;
  final String label;
  final double amount;
  final int dayOfMonth;

  Map<String, Object?> toMap() => <String, Object?>{
    if (id != null) 'id': id,
    'wallet_id': walletId,
    'label': label,
    'amount': amount,
    'day_of_month': dayOfMonth,
  };

  Payout copyWith({
    int? id,
    int? walletId,
    String? label,
    double? amount,
    int? dayOfMonth,
  }) => Payout(
    id: id ?? this.id,
    walletId: walletId ?? this.walletId,
    label: label ?? this.label,
    amount: amount ?? this.amount,
    dayOfMonth: dayOfMonth ?? this.dayOfMonth,
  );
}
