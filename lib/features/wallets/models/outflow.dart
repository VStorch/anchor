import '../../../core/utils/month.dart';

class Outflow {
  const Outflow({
    this.id,
    required this.walletId,
    required this.description,
    required this.amount,
    required this.spentAt,
  });

  factory Outflow.fromMap(Map<String, Object?> map) => Outflow(
    id: map['id'] as int?,
    walletId: map['wallet_id'] as int,
    description: map['description'] as String,
    amount: (map['amount'] as num).toDouble(),
    spentAt: DateTime.parse(map['spent_at'] as String),
  );

  final int? id;
  final int walletId;
  final String description;
  final double amount;
  final DateTime spentAt;

  Month get month => Month.fromDate(spentAt);

  String get label => description.trim().isEmpty ? 'Gasto' : description.trim();

  Map<String, Object?> toMap() => <String, Object?>{
    if (id != null) 'id': id,
    'wallet_id': walletId,
    'month_key': month.key,
    'description': description.trim(),
    'amount': amount,
    'spent_at': spentAt.toIso8601String(),
  };

  Outflow copyWith({String? description, double? amount, DateTime? spentAt}) =>
      Outflow(
        id: id,
        walletId: walletId,
        description: description ?? this.description,
        amount: amount ?? this.amount,
        spentAt: spentAt ?? this.spentAt,
      );
}
