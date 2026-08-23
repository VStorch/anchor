import '../../expenses/models/expense.dart';
import '../../wallets/models/receipt.dart';
import '../../wallets/models/wallet.dart';
import 'month_summary.dart';
import 'wallet_summary.dart';

class BudgetSnapshot {
  const BudgetSnapshot({
    required this.summary,
    required this.walletSummaries,
    required this.expenses,
    required this.wallets,
    required this.receipts,
  });

  factory BudgetSnapshot.empty(MonthSummary summary) => BudgetSnapshot(
    summary: summary,
    walletSummaries: const <WalletSummary>[],
    expenses: const <Expense>[],
    wallets: const <Wallet>[],
    receipts: const <Receipt>[],
  );

  final MonthSummary summary;
  final List<WalletSummary> walletSummaries;
  final List<Expense> expenses;
  final List<Wallet> wallets;
  final List<Receipt> receipts;

  bool get hasWallets => wallets.isNotEmpty;

  WalletSummary? summaryFor(int? walletId) {
    if (walletId == null) return null;
    for (final summary in walletSummaries) {
      if (summary.wallet.id == walletId) return summary;
    }
    return null;
  }

  Wallet? walletById(int? id) => summaryFor(id)?.wallet;
}
