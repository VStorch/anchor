import 'package:flutter/material.dart';

import '../../../app/theme/app_palette.dart';
import 'payout.dart';
import 'receipt.dart';
import 'wallet_kind.dart';

class Wallet {
  const Wallet({
    this.id,
    required this.name,
    required this.kind,
    required this.colorIndex,
    required this.createdAt,
    this.payouts = const <Payout>[],
    this.monthlyReserve,
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
    monthlyReserve: (map['monthly_reserve'] as num?)?.toDouble(),
  );

  final int? id;
  final String name;
  final WalletKind kind;
  final int colorIndex;
  final DateTime createdAt;
  final List<Payout> payouts;

  /// What a salary sets aside each month for everyday spending (groceries,
  /// transport), outside any bill; null when the user never said.
  final double? monthlyReserve;

  Color get color => AppPalette.walletColorAt(colorIndex);

  IconData get icon => kind == WalletKind.salary
      ? Icons.account_balance_wallet_outlined
      : Icons.card_giftcard_outlined;

  double get monthlyIncome =>
      payouts.fold(0, (total, payout) => total + payout.amount);

  bool get hasSchedule => payouts.isNotEmpty;

  Payout? payoutById(int? id) {
    if (id == null) return null;
    for (final payout in payouts) {
      if (payout.id == id) return payout;
    }
    return null;
  }

  /// What a receipt is called on screen. With a single payout there is
  /// nothing to tell apart, so the wallet name is the whole title; money
  /// with no payout behind it — or whose payout was deleted — is an extra.
  String titleFor(Receipt receipt) {
    final payout = payoutById(receipt.payoutId);
    return payout == null ? extraIncomeTitle : titleOf(payout);
  }

  String titleOf(Payout payout) =>
      payouts.length < 2 ? name : '$name · ${payout.nameOrSchedule}';

  /// The movement subtitle drops the wallet name when the title already is it.
  bool titleIsWalletName(Receipt receipt) =>
      payouts.length < 2 && payoutById(receipt.payoutId) != null;

  static const String extraIncomeTitle = 'Entrada extra';

  Map<String, Object?> toMap() => <String, Object?>{
    if (id != null) 'id': id,
    'name': name,
    'kind': kind.id,
    'color_index': colorIndex,
    'created_at': createdAt.toIso8601String(),
    'monthly_reserve': monthlyReserve,
  };

  Wallet copyWith({
    int? id,
    String? name,
    WalletKind? kind,
    int? colorIndex,
    DateTime? createdAt,
    List<Payout>? payouts,
    double? monthlyReserve,
    bool clearMonthlyReserve = false,
  }) => Wallet(
    id: id ?? this.id,
    name: name ?? this.name,
    kind: kind ?? this.kind,
    colorIndex: colorIndex ?? this.colorIndex,
    createdAt: createdAt ?? this.createdAt,
    payouts: payouts ?? this.payouts,
    monthlyReserve: clearMonthlyReserve
        ? null
        : monthlyReserve ?? this.monthlyReserve,
  );
}
