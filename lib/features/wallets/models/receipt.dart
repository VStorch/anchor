import '../../../core/utils/month.dart';
import 'receipt_status.dart';

class Receipt {
  const Receipt({
    this.id,
    required this.walletId,
    this.payoutId,
    required this.month,
    required this.amount,
    required this.receivedAt,
    this.status = ReceiptStatus.confirmed,
    this.pendingAtCheckId,
  });

  factory Receipt.fromMap(Map<String, Object?> map) => Receipt(
    id: map['id'] as int?,
    walletId: map['wallet_id'] as int,
    payoutId: map['payout_id'] as int?,
    month: Month.fromKey(map['month_key'] as String),
    amount: (map['amount'] as num).toDouble(),
    receivedAt: DateTime.parse(map['received_at'] as String),
    status: ReceiptStatus.fromId(map['status'] as String),
    pendingAtCheckId: map['pending_at_check_id'] as int?,
  );

  final int? id;
  final int walletId;
  final int? payoutId;
  final Month month;
  final double amount;
  final DateTime receivedAt;
  final ReceiptStatus status;

  /// The balance check this receipt was left out of as "not arrived yet":
  /// once confirmed it counts after that check, whatever day it is dated.
  final int? pendingAtCheckId;

  bool get isManual => payoutId == null;

  bool get isPredicted => status == ReceiptStatus.predicted;

  bool get isConfirmed => status == ReceiptStatus.confirmed;

  bool get counts => status != ReceiptStatus.skipped;

  Map<String, Object?> toMap() => <String, Object?>{
    if (id != null) 'id': id,
    'wallet_id': walletId,
    'payout_id': payoutId,
    'month_key': month.key,
    'amount': amount,
    'received_at': receivedAt.toIso8601String(),
    'status': status.id,
    'pending_at_check_id': pendingAtCheckId,
  };

  Receipt copyWith({
    double? amount,
    DateTime? receivedAt,
    ReceiptStatus? status,
  }) => Receipt(
    id: id,
    walletId: walletId,
    payoutId: payoutId,
    month: isManual && receivedAt != null ? Month.fromDate(receivedAt) : month,
    amount: amount ?? this.amount,
    receivedAt: receivedAt ?? this.receivedAt,
    status: status ?? this.status,
    pendingAtCheckId: pendingAtCheckId,
  );
}
