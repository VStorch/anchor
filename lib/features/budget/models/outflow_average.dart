import '../../../core/utils/money.dart';
import '../../../core/utils/month.dart';
import '../../wallets/models/outflow.dart';
import '../../wallets/models/wallet.dart';

/// What a wallet's everyday spending came to in the last full months that
/// had any, offered as the reserve instead of a guess.
class OutflowAverage {
  const OutflowAverage({
    required this.amount,
    required this.from,
    required this.to,
  });

  final double amount;
  final Month from;
  final Month to;

  static const int _months = 3;

  /// Only full months count: after the one the wallet was created in, which
  /// started halfway, and before the current one, still running. A month
  /// with no outflow launched says the user was not tracking, not that
  /// nothing was spent, so it is left out.
  static OutflowAverage? of({
    required Wallet wallet,
    required List<Outflow> outflows,
    required DateTime today,
  }) {
    final created = Month.fromDate(wallet.createdAt);
    final current = Month.fromDate(today);
    final totals = <Month, double>{};
    for (final outflow in outflows) {
      if (outflow.walletId != wallet.id) continue;
      final month = outflow.month;
      if (month <= created || month >= current) continue;
      totals[month] = (totals[month] ?? 0) + outflow.amount;
    }
    if (totals.isEmpty) return null;

    final months = totals.keys.toList()..sort();
    final recent = months.sublist(
      months.length > _months ? months.length - _months : 0,
    );
    final sum = recent.fold<double>(
      0,
      (total, month) => total + totals[month]!,
    );

    return OutflowAverage(
      amount: roundCents(sum / recent.length),
      from: recent.first,
      to: recent.last,
    );
  }
}
