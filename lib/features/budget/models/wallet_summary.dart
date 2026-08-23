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
  });

  static List<WalletSummary> buildAll({
    required Month month,
    required List<Wallet> wallets,
    required List<Receipt> receipts,
    required List<ExpensePayment> payments,
    required List<ExpenseOccurrence> occurrences,
  }) {
    return wallets.map((wallet) {
      final walletReceipts = receipts.where((r) => r.walletId == wallet.id);
      final walletPayments = payments.where((p) => p.walletId == wallet.id);

      final totalIn = walletReceipts.fold<double>(
        0,
        (sum, r) => sum + r.amount,
      );
      final totalOut = walletPayments.fold<double>(
        0,
        (sum, p) => sum + p.amount,
      );

      return WalletSummary(
        wallet: wallet,
        receivedInMonth: walletReceipts
            .where((r) => r.month == month)
            .fold(0, (sum, r) => sum + r.amount),
        spentInMonth: walletPayments
            .where((p) => p.month == month)
            .fold(0, (sum, p) => sum + p.amount),
        committedInMonth: occurrences
            .where((o) => o.walletId == wallet.id)
            .fold(0, (sum, o) => sum + o.amount),
        balance: totalIn - totalOut,
      );
    }).toList();
  }

  final Wallet wallet;
  final double receivedInMonth;
  final double spentInMonth;
  final double committedInMonth;
  final double balance;

  double get pendingInMonth => committedInMonth - spentInMonth;

  double get usageRatio =>
      receivedInMonth <= 0 ? 0 : (spentInMonth / receivedInMonth).clamp(0, 1);
}
