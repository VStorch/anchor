import '../../../core/utils/money.dart';
import '../../../core/utils/month.dart';
import '../../expenses/models/expense_occurrence.dart';
import '../../wallets/models/payout.dart';
import '../../wallets/models/receipt.dart';
import '../../wallets/models/wallet.dart';
import '../../wallets/models/wallet_kind.dart';
import 'everyday_spending.dart';
import 'month_summary.dart';
import 'wallet_summary.dart';

/// The part of a reserve that one month takes.
class ReserveShare {
  const ReserveShare({required this.month, required this.amount});

  final Month month;
  final double amount;
}

class WalletForecast {
  const WalletForecast({
    required this.wallet,
    required this.startBalance,
    required this.toReceive,
    required this.toPay,
    this.reserveShares = const <ReserveShare>[],
  });

  final Wallet wallet;
  final double startBalance;
  final double toReceive;
  final double toPay;

  /// The everyday spending set aside, month by month, up to the month on
  /// screen: what is left of this month's, then each later month whole.
  final List<ReserveShare> reserveShares;

  double get reserve => roundCents(
    reserveShares.fold<double>(0, (total, share) => total + share.amount),
  );

  double get endBalance =>
      roundCents(startBalance + toReceive - toPay - reserve);
}

/// The wallets of one kind of money, forecast together. Free money and
/// benefit money are two groups because a meal voucher never pays the rent:
/// no screen adds them up.
class ForecastGroup {
  const ForecastGroup({
    required this.wallets,
    this.unassignedToPay = 0,
    this.daysLeft,
  });

  final List<WalletForecast> wallets;

  /// Bills with no wallet behind them; only free money can pay those.
  final double unassignedToPay;

  /// Days from today to the end of the month, today included; null when the
  /// forecast is of a later month.
  final int? daysLeft;

  /// What the group's wallets hold today, where the forecast starts.
  double get startBalance => roundCents(
    wallets.fold<double>(0, (total, wallet) => total + wallet.startBalance),
  );

  double get toReceive => roundCents(
    wallets.fold<double>(0, (total, wallet) => total + wallet.toReceive),
  );

  double get toPay => roundCents(
    wallets.fold<double>(0, (total, wallet) => total + wallet.toPay),
  );

  double get reserve => roundCents(
    wallets.fold<double>(0, (total, wallet) => total + wallet.reserve),
  );

  /// The reserve summed month by month, for the line that explains it.
  List<ReserveShare> get reserveShares {
    final byMonth = <Month, double>{};
    for (final wallet in wallets) {
      for (final share in wallet.reserveShares) {
        byMonth[share.month] = (byMonth[share.month] ?? 0) + share.amount;
      }
    }
    final months = byMonth.keys.toList()..sort();
    return [
      for (final month in months)
        ReserveShare(month: month, amount: roundCents(byMonth[month]!)),
    ];
  }

  bool get hasReserve =>
      wallets.any((forecast) => forecast.wallet.monthlyReserve != null);

  double get endBalance => roundCents(
    wallets.fold<double>(0, (total, wallet) => total + wallet.endBalance) -
        unassignedToPay,
  );

  /// How much can go out per day until the month ends without breaking the
  /// plan. With a reserve, the plan is to live on it and keep the leftover,
  /// so the day's share is what is left of the reserve — never more than the
  /// month really leaves. With none, it is everything the month leaves.
  /// Only for the current month: a later month has no "today".
  double? get dailyAllowance {
    final days = daysLeft;
    if (days == null || days <= 0 || wallets.isEmpty) return null;
    final available = endBalance + reserve;
    final spendable = available <= 0
        ? 0.0
        : hasReserve && reserve < available
        ? reserve
        : available;
    return roundCents(spendable / days);
  }

  bool get isEmpty => wallets.isEmpty && unassignedToPay <= 0;

  /// There are salaries and none of them says what the everyday spending
  /// takes, so the forecast is more optimistic than it should be.
  bool get lacksReserve =>
      wallets.any((forecast) => forecast.wallet.kind == WalletKind.salary) &&
      !hasReserve;
}

/// Where the money is headed from today to the end of [month]: what the
/// wallets hold now, plus what is still expected in, minus what is still owed.
/// It holds no figure of what already happened in the month.
class MonthForecast {
  const MonthForecast({
    required this.month,
    required this.wallets,
    required this.unassignedToPay,
    this.daysLeft,
  });

  final Month month;
  final List<WalletForecast> wallets;
  final double unassignedToPay;

  /// Days left in the current month, today included; null for a later one.
  final int? daysLeft;

  static MonthForecast? build({
    required Month month,
    required DateTime today,
    required List<WalletSummary> walletSummaries,
    required List<Receipt> receipts,
    required List<MonthSummary> monthsAhead,
    required List<EverydaySpending> spending,
  }) {
    final currentMonth = Month.fromDate(today);
    if (month < currentMonth) return null;

    final months = monthsAhead
        .where((summary) => summary.month >= currentMonth)
        .where((summary) => summary.month <= month)
        .toList();
    final occurrences = months.expand((summary) => summary.occurrences);
    final walletIds = walletSummaries.map((summary) => summary.wallet.id);
    final daysLeft = currentMonth.lengthInDays - today.day + 1;

    return MonthForecast(
      month: month,
      daysLeft: month == currentMonth ? daysLeft : null,
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
            reserveShares: _reserveOf(
              summary.wallet,
              month: month,
              currentMonth: currentMonth,
              daysLeft: daysLeft,
              spending: spending,
            ),
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

  /// The current month keeps its share of the reserve for the days still
  /// ahead — a reserve set on the 16th does not take the whole month — and
  /// never more than what the month's everyday spending left of it. Every
  /// later month up to [month] takes the reserve whole. Only a salary sets
  /// money aside: a benefit's balance already is what is left for food.
  static List<ReserveShare> _reserveOf(
    Wallet wallet, {
    required Month month,
    required Month currentMonth,
    required int daysLeft,
    required List<EverydaySpending> spending,
  }) {
    final reserve = wallet.monthlyReserve;
    if (reserve == null || wallet.kind != WalletKind.salary) {
      return const <ReserveShare>[];
    }

    final spent = spending
        .where((item) => item.walletId == wallet.id)
        .where((item) => item.month == currentMonth)
        .fold<double>(0, (total, item) => total + item.amount);
    final unspent = reserve - spent;
    final ahead = reserve * daysLeft / currentMonth.lengthInDays;
    final current = unspent < ahead ? unspent : ahead;

    return [
      ReserveShare(
        month: currentMonth,
        amount: roundCents(current > 0 ? current : 0),
      ),
      for (var later = currentMonth.next; later <= month; later = later.next)
        ReserveShare(month: later, amount: reserve),
    ];
  }

  static bool _isActive(Payout payout, Wallet wallet, Month month) =>
      month >= payout.startMonth && month >= Month.fromDate(wallet.createdAt);

  ForecastGroup get freeMoney => ForecastGroup(
    wallets: _ofKind(WalletKind.salary),
    unassignedToPay: unassignedToPay,
    daysLeft: daysLeft,
  );

  ForecastGroup get benefits =>
      ForecastGroup(wallets: _ofKind(WalletKind.benefit), daysLeft: daysLeft);

  /// Benefits whose planned bills are more than they will hold.
  List<WalletForecast> get shortBenefits =>
      benefits.wallets.where((wallet) => wallet.endBalance < 0).toList();

  List<WalletForecast> _ofKind(WalletKind kind) =>
      wallets.where((forecast) => forecast.wallet.kind == kind).toList();
}
