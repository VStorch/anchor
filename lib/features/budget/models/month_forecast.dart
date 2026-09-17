import '../../../core/utils/money.dart';
import '../../../core/utils/month.dart';
import '../../expenses/models/expense_occurrence.dart';
import '../../wallets/models/payout.dart';
import '../../wallets/models/receipt.dart';
import '../../wallets/models/wallet.dart';
import '../../wallets/models/wallet_kind.dart';
import 'month_summary.dart';
import 'wallet_summary.dart';

class WalletForecast {
  const WalletForecast({
    required this.wallet,
    required this.startBalance,
    required this.toReceive,
    required this.toPay,
  });

  final Wallet wallet;
  final double startBalance;
  final double toReceive;
  final double toPay;

  double get endBalance => roundCents(startBalance + toReceive - toPay);
}

/// The wallets of one kind of money, forecast together. Free money and
/// benefit money are two groups because a meal voucher never pays the rent:
/// no screen adds them up.
class ForecastGroup {
  const ForecastGroup({required this.wallets, this.unassignedToPay = 0});

  final List<WalletForecast> wallets;

  /// Bills with no wallet behind them; only free money can pay those.
  final double unassignedToPay;

  double get toReceive => roundCents(
    wallets.fold<double>(0, (total, wallet) => total + wallet.toReceive),
  );

  double get toPay => roundCents(
    wallets.fold<double>(0, (total, wallet) => total + wallet.toPay),
  );

  double get endBalance => roundCents(
    wallets.fold<double>(0, (total, wallet) => total + wallet.endBalance) -
        unassignedToPay,
  );

  bool get isEmpty => wallets.isEmpty && unassignedToPay <= 0;
}

/// Where the money is headed from today to the end of [month]: what the
/// wallets hold now, plus what is still expected in, minus what is still owed.
/// It holds no figure of what already happened in the month.
class MonthForecast {
  const MonthForecast({
    required this.month,
    required this.wallets,
    required this.unassignedToPay,
  });

  final Month month;
  final List<WalletForecast> wallets;
  final double unassignedToPay;

  static MonthForecast? build({
    required Month month,
    required DateTime today,
    required List<WalletSummary> walletSummaries,
    required List<Receipt> receipts,
    required List<MonthSummary> monthsAhead,
  }) {
    final currentMonth = Month.fromDate(today);
    if (month < currentMonth) return null;

    final months = monthsAhead
        .where((summary) => summary.month >= currentMonth)
        .where((summary) => summary.month <= month)
        .toList();
    final occurrences = months.expand((summary) => summary.occurrences);
    final walletIds = walletSummaries.map((summary) => summary.wallet.id);

    return MonthForecast(
      month: month,
      wallets: [
        for (final summary in walletSummaries)
          WalletForecast(
            wallet: summary.wallet,
            startBalance: summary.balance,
            toReceive: roundCents(
              months.fold(
                0,
                (total, ahead) =>
                    total + _expectedIn(summary.wallet, ahead.month, receipts),
              ),
            ),
            toPay: occurrences
                .where(
                  (occurrence) =>
                      occurrence.plannedWalletId == summary.wallet.id,
                )
                .totalRemaining,
          ),
      ],
      unassignedToPay: occurrences
          .where(
            (occurrence) => !walletIds.contains(occurrence.plannedWalletId),
          )
          .totalRemaining,
    );
  }

  /// A predicted receipt still waits to be confirmed, even when its day has
  /// gone by; a payout the calendar has not turned into a receipt yet is
  /// expected in full, while a confirmed or skipped one expects nothing.
  static double _expectedIn(
    Wallet wallet,
    Month month,
    List<Receipt> receipts,
  ) {
    final monthReceipts = receipts.where(
      (receipt) => receipt.walletId == wallet.id && receipt.month == month,
    );
    final predicted = monthReceipts
        .where((receipt) => receipt.isPredicted)
        .fold<double>(0, (total, receipt) => total + receipt.amount);
    final scheduled = wallet.payouts
        .where((payout) => _isActive(payout, wallet, month))
        .where(
          (payout) =>
              monthReceipts.every((receipt) => receipt.payoutId != payout.id),
        )
        .fold<double>(0, (total, payout) => total + payout.amount);
    return predicted + scheduled;
  }

  static bool _isActive(Payout payout, Wallet wallet, Month month) =>
      month >= payout.startMonth && month >= Month.fromDate(wallet.createdAt);

  ForecastGroup get freeMoney => ForecastGroup(
    wallets: _ofKind(WalletKind.salary),
    unassignedToPay: unassignedToPay,
  );

  ForecastGroup get benefits =>
      ForecastGroup(wallets: _ofKind(WalletKind.benefit));

  /// Benefits whose planned bills are more than they will hold.
  List<WalletForecast> get shortBenefits =>
      benefits.wallets.where((wallet) => wallet.endBalance < 0).toList();

  List<WalletForecast> _ofKind(WalletKind kind) =>
      wallets.where((forecast) => forecast.wallet.kind == kind).toList();
}
