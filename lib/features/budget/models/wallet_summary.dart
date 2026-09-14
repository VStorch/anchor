import '../../../core/utils/money.dart';
import '../../../core/utils/month.dart';
import '../../expenses/models/expense_occurrence.dart';
import '../../expenses/models/expense_payment.dart';
import '../../wallets/models/balance_check.dart';
import '../../wallets/models/outflow.dart';
import '../../wallets/models/receipt.dart';
import '../../wallets/models/wallet.dart';

class WalletSummary {
  const WalletSummary({
    required this.wallet,
    required this.receivedInMonth,
    required this.spentInMonth,
    required this.committedInMonth,
    required this.balance,
    required this.unconfirmedInMonth,
    this.pendingConfirmationInMonth = 0,
    this.latestCheck,
  });

  static List<WalletSummary> buildAll({
    required Month month,
    required List<Wallet> wallets,
    required List<Receipt> receipts,
    required List<ExpensePayment> payments,
    required List<ExpenseOccurrence> occurrences,
    required List<BalanceCheck> checks,
    List<Outflow> outflows = const <Outflow>[],
  }) {
    return wallets.map((wallet) {
      final latestCheck = _latestOf(
        checks.where((check) => check.walletId == wallet.id),
      );
      bool counts(DateTime at) => _countsAfter(latestCheck, at);

      final walletReceipts = receipts.where(
        (receipt) => receipt.walletId == wallet.id && receipt.counts,
      );
      final confirmedReceipts = walletReceipts.where(
        (receipt) => receipt.isConfirmed,
      );
      final walletPayments = payments.where(
        (payment) => !payment.settledOutside && payment.walletId == wallet.id,
      );
      final walletOutflows = outflows.where(
        (outflow) => outflow.walletId == wallet.id,
      );
      final predictedInMonth = walletReceipts.where(
        (receipt) => receipt.month == month && receipt.isPredicted,
      );

      final spentInMonth =
          walletPayments
              .where((payment) => payment.month == month)
              .fold<double>(0, (total, payment) => total + payment.amount) +
          walletOutflows
              .where((outflow) => outflow.month == month)
              .fold<double>(0, (total, outflow) => total + outflow.amount);

      final plannedRemainder = occurrences
          .where((occurrence) => occurrence.plannedWalletId == wallet.id)
          .totalRemaining;

      final balance =
          (latestCheck?.amount ?? 0) +
          confirmedReceipts
              .where((receipt) => counts(receipt.receivedAt))
              .fold<double>(0, (total, receipt) => total + receipt.amount) -
          walletPayments
              .where((payment) => counts(payment.paidAt))
              .fold<double>(0, (total, payment) => total + payment.amount) -
          walletOutflows
              .where((outflow) => counts(outflow.spentAt))
              .fold<double>(0, (total, outflow) => total + outflow.amount);

      return WalletSummary(
        wallet: wallet,
        receivedInMonth: roundCents(
          confirmedReceipts
              .where((receipt) => receipt.month == month)
              .fold(0, (total, receipt) => total + receipt.amount),
        ),
        spentInMonth: roundCents(spentInMonth),
        committedInMonth: roundCents(spentInMonth + plannedRemainder),
        balance: roundCents(balance),
        unconfirmedInMonth: predictedInMonth.length,
        pendingConfirmationInMonth: roundCents(
          predictedInMonth.fold(0, (total, receipt) => total + receipt.amount),
        ),
        latestCheck: latestCheck,
      );
    }).toList();
  }

  static BalanceCheck? _latestOf(Iterable<BalanceCheck> checks) {
    BalanceCheck? latest;
    for (final check in checks) {
      if (latest == null || !check.checkedAt.isBefore(latest.checkedAt)) {
        latest = check;
      }
    }
    return latest;
  }

  static bool _countsAfter(BalanceCheck? check, DateTime at) =>
      check == null || at.isAfter(check.checkedAt);

  final Wallet wallet;
  final double receivedInMonth;
  final double spentInMonth;
  final double committedInMonth;
  final double balance;
  final int unconfirmedInMonth;
  final double pendingConfirmationInMonth;
  final BalanceCheck? latestCheck;

  /// Whatever is dated up to the latest check is already inside its amount.
  bool countsInBalance(DateTime at) => _countsAfter(latestCheck, at);

  double get pendingInMonth => roundCents(committedInMonth - spentInMonth);

  double get usageRatio =>
      receivedInMonth <= 0 ? 0 : (spentInMonth / receivedInMonth).clamp(0, 1);
}
