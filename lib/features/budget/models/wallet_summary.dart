import '../../../core/utils/month.dart';
import '../../expenses/models/expense_occurrence.dart';
import '../../expenses/models/expense_payment.dart';
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
  });

  static List<WalletSummary> buildAll({
    required Month month,
    required List<Wallet> wallets,
    required List<Receipt> receipts,
    required List<ExpensePayment> payments,
    required List<ExpenseOccurrence> occurrences,
  }) {
    return wallets.map((wallet) {
      final walletReceipts = receipts.where(
        (receipt) => receipt.walletId == wallet.id && receipt.counts,
      );
      final walletPayments = payments.where(
        (payment) => payment.walletId == wallet.id,
      );
      final monthReceipts = walletReceipts.where(
        (receipt) => receipt.month == month,
      );
      final monthIncome = monthReceipts.where(
        (receipt) => !receipt.isAdjustment,
      );

      final spentInMonth = walletPayments
          .where((payment) => payment.month == month)
          .fold<double>(0, (total, payment) => total + payment.amount);

      final plannedRemainder = occurrences
          .where((occurrence) => occurrence.plannedWalletId == wallet.id)
          .fold<double>(0, (total, occurrence) => total + occurrence.remaining);

      return WalletSummary(
        wallet: wallet,
        receivedInMonth: monthIncome.fold(
          0,
          (total, receipt) => total + receipt.amount,
        ),
        spentInMonth: spentInMonth,
        committedInMonth: spentInMonth + plannedRemainder,
        balance:
            walletReceipts.fold<double>(
              0,
              (total, receipt) => total + receipt.amount,
            ) -
            walletPayments.fold<double>(
              0,
              (total, payment) => total + payment.amount,
            ),
        unconfirmedInMonth: monthIncome
            .where((receipt) => receipt.isPredicted)
            .length,
      );
    }).toList();
  }

  final Wallet wallet;
  final double receivedInMonth;
  final double spentInMonth;
  final double committedInMonth;
  final double balance;
  final int unconfirmedInMonth;

  double get pendingInMonth => committedInMonth - spentInMonth;

  double get usageRatio =>
      receivedInMonth <= 0 ? 0 : (spentInMonth / receivedInMonth).clamp(0, 1);
}
