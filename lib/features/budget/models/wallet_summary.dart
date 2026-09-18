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
    this.checkAmount = 0,
    this.receivedSinceCheck = 0,
    this.spentSinceCheck = 0,
    this.receivedInMonthBeforeCheck = 0,
    this.spentInMonthBeforeCheck = 0,
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
      bool countsReceipt(Receipt receipt) =>
          _countsReceiptAfter(latestCheck, receipt);

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

      final paidInMonth = walletPayments.where(
        (payment) => payment.month == month,
      );
      final outInMonth = walletOutflows.where(
        (outflow) => outflow.month == month,
      );
      final spentInMonth = _paid(paidInMonth) + _spent(outInMonth);

      final plannedRemainder = occurrences
          .where((occurrence) => occurrence.plannedWalletId == wallet.id)
          .totalRemaining;

      final checkAmount = roundCents(latestCheck?.amount ?? 0);
      final receivedSinceCheck = roundCents(
        _received(confirmedReceipts.where(countsReceipt)),
      );
      final spentSinceCheck = roundCents(
        _paid(walletPayments.where((payment) => counts(payment.paidAt))) +
            _spent(walletOutflows.where((outflow) => counts(outflow.spentAt))),
      );

      return WalletSummary(
        wallet: wallet,
        receivedInMonth: roundCents(
          _received(
            confirmedReceipts.where((receipt) => receipt.month == month),
          ),
        ),
        spentInMonth: roundCents(spentInMonth),
        committedInMonth: roundCents(spentInMonth + plannedRemainder),
        balance: roundCents(checkAmount + receivedSinceCheck - spentSinceCheck),
        unconfirmedInMonth: predictedInMonth.length,
        pendingConfirmationInMonth: roundCents(_received(predictedInMonth)),
        checkAmount: checkAmount,
        receivedSinceCheck: receivedSinceCheck,
        spentSinceCheck: spentSinceCheck,
        receivedInMonthBeforeCheck: roundCents(
          _received(
            confirmedReceipts.where(
              (receipt) => receipt.month == month && !countsReceipt(receipt),
            ),
          ),
        ),
        spentInMonthBeforeCheck: roundCents(
          _paid(paidInMonth.where((payment) => !counts(payment.paidAt))) +
              _spent(outInMonth.where((outflow) => !counts(outflow.spentAt))),
        ),
        latestCheck: latestCheck,
      );
    }).toList();
  }

  static double _received(Iterable<Receipt> receipts) =>
      receipts.fold(0, (total, receipt) => total + receipt.amount);

  static double _paid(Iterable<ExpensePayment> payments) =>
      payments.fold(0, (total, payment) => total + payment.amount);

  static double _spent(Iterable<Outflow> outflows) =>
      outflows.fold(0, (total, outflow) => total + outflow.amount);

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

  static bool _countsReceiptAfter(BalanceCheck? check, Receipt receipt) =>
      _countsAfter(check, receipt.receivedAt) ||
      (receipt.pendingAtCheckId != null &&
          receipt.pendingAtCheckId == check?.id);

  final Wallet wallet;
  final double receivedInMonth;
  final double spentInMonth;
  final double committedInMonth;
  final double balance;
  final int unconfirmedInMonth;
  final double pendingConfirmationInMonth;

  /// The three figures the balance is made of: what was informed, and what
  /// came in and left after it — `checkAmount + received - spent == balance`.
  final double checkAmount;
  final double receivedSinceCheck;
  final double spentSinceCheck;

  /// What the month moved that the informed balance already contains.
  final double receivedInMonthBeforeCheck;
  final double spentInMonthBeforeCheck;
  final BalanceCheck? latestCheck;

  /// Whatever is dated up to the latest check is already inside its amount.
  bool countsInBalance(DateTime at) => _countsAfter(latestCheck, at);

  /// A receipt left unticked as "not arrived yet" when the latest check was
  /// informed counts after it, even dated before it.
  bool countsReceipt(Receipt receipt) =>
      _countsReceiptAfter(latestCheck, receipt);

  bool get hasMovementBeforeCheck =>
      receivedInMonthBeforeCheck > 0 || spentInMonthBeforeCheck > 0;

  double get pendingInMonth => roundCents(committedInMonth - spentInMonth);

  /// How much of the money the wallet had is still there: the balance over
  /// the balance plus what left since the latest check (or since the wallet
  /// was created). It reads the balance, so the bar never says there is more
  /// than there is.
  double get leftRatio {
    final had = balance + spentSinceCheck;
    if (balance <= 0 || had <= 0) return 0;
    return (balance / had).clamp(0, 1);
  }
}
