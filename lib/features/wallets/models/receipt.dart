import '../../../core/utils/month.dart';
import 'receipt_kind.dart';
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
    this.kind = ReceiptKind.income,
  });

  factory Receipt.fromMap(Map<String, Object?> map) => Receipt(
    id: map['id'] as int?,
    walletId: map['wallet_id'] as int,
    payoutId: map['payout_id'] as int?,
    month: Month.fromKey(map['month_key'] as String),
    amount: (map['amount'] as num).toDouble(),
    receivedAt: DateTime.parse(map['received_at'] as String),
    status: ReceiptStatus.fromId(map['status'] as String),
    kind: ReceiptKind.fromId(map['kind'] as String),
  );

  final int? id;
  final int walletId;
  final int? payoutId;
  final Month month;
  final double amount;
  final DateTime receivedAt;
  final ReceiptStatus status;
  final ReceiptKind kind;

  bool get isManual => payoutId == null;

  bool get isAdjustment => kind == ReceiptKind.adjustment;

  bool get isPredicted => status == ReceiptStatus.predicted;

  bool get counts => status != ReceiptStatus.skipped;

  Map<String, Object?> toMap() => <String, Object?>{
    if (id != null) 'id': id,
    'wallet_id': walletId,
    'payout_id': payoutId,
    'month_key': month.key,
    'amount': amount,
    'received_at': receivedAt.toIso8601String(),
    'status': status.id,
    'kind': kind.id,
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
    kind: kind,
  );
}
