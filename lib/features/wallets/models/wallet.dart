import 'package:flutter/material.dart';

import '../../../app/theme/app_palette.dart';
import 'payout.dart';
import 'wallet_kind.dart';

class Wallet {
  const Wallet({
    this.id,
    required this.name,
    required this.kind,
    required this.colorIndex,
    required this.createdAt,
    this.payouts = const <Payout>[],
  });

  factory Wallet.fromMap(
    Map<String, Object?> map, {
    List<Payout> payouts = const <Payout>[],
  }) => Wallet(
    id: map['id'] as int?,
    name: map['name'] as String,
    kind: WalletKind.fromId(map['kind'] as String),
    colorIndex: map['color_index'] as int,
    createdAt: DateTime.parse(map['created_at'] as String),
    payouts: payouts,
  );

  final int? id;
  final String name;
  final WalletKind kind;
  final int colorIndex;
  final DateTime createdAt;
  final List<Payout> payouts;

  Color get color => AppPalette.walletColorAt(colorIndex);

  IconData get icon => kind == WalletKind.salary
      ? Icons.account_balance_wallet_outlined
      : Icons.card_giftcard_outlined;

  double get monthlyIncome =>
      payouts.fold(0, (total, payout) => total + payout.amount);

  bool get hasSchedule => payouts.isNotEmpty;

  Map<String, Object?> toMap() => <String, Object?>{
    if (id != null) 'id': id,
    'name': name,
    'kind': kind.id,
    'color_index': colorIndex,
    'created_at': createdAt.toIso8601String(),
  };

  Wallet copyWith({
    int? id,
    String? name,
    WalletKind? kind,
    int? colorIndex,
    DateTime? createdAt,
    List<Payout>? payouts,
  }) => Wallet(
    id: id ?? this.id,
    name: name ?? this.name,
    kind: kind ?? this.kind,
    colorIndex: colorIndex ?? this.colorIndex,
    createdAt: createdAt ?? this.createdAt,
    payouts: payouts ?? this.payouts,
  );
}
