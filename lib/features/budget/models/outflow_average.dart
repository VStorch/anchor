import '../../../core/utils/money.dart';
import '../../../core/utils/month.dart';
import '../../wallets/models/wallet.dart';
import 'everyday_spending.dart';

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

  /// Only full months count: the current one is still running. Months
  /// before the wallet was created count too — spending typed in for them is
  /// history the user chose to give. A month with nothing launched says the
  /// user was not tracking, not that nothing was spent, so it is left out.
  static OutflowAverage? of({
    required Wallet wallet,
    required List<EverydaySpending> spending,
    required DateTime today,
  }) {
    final current = Month.fromDate(today);
    final totals = <Month, double>{};
    for (final item in spending) {
      if (item.walletId != wallet.id) continue;
      final month = item.month;
      if (month >= current) continue;
      totals[month] = (totals[month] ?? 0) + item.amount;
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
