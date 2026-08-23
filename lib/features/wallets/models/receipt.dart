import '../../../core/utils/month.dart';

class Receipt {
  const Receipt({
    this.id,
    required this.walletId,
    this.payoutId,
    required this.month,
    required this.amount,
    required this.receivedAt,
  });

  factory Receipt.fromMap(Map<String, Object?> map) => Receipt(
    id: map['id'] as int?,
    walletId: map['wallet_id'] as int,
    payoutId: map['payout_id'] as int?,
    month: Month.fromKey(map['month_key'] as String),
    amount: (map['amount'] as num).toDouble(),
    receivedAt: DateTime.parse(map['received_at'] as String),
  );

  final int? id;
  final int walletId;
  final int? payoutId;
  final Month month;
  final double amount;
  final DateTime receivedAt;

  bool get isManual => payoutId == null;

  Map<String, Object?> toMap() => <String, Object?>{
    if (id != null) 'id': id,
    'wallet_id': walletId,
    'payout_id': payoutId,
    'month_key': month.key,
    'amount': amount,
    'received_at': receivedAt.toIso8601String(),
  };
}
