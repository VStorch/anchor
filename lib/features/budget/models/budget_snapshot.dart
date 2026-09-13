import '../../cards/models/credit_card.dart';
import '../../expenses/models/expense.dart';
import '../../expenses/models/expense_payment.dart';
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
    required this.payments,
    this.cards = const <CreditCard>[],
  });

  factory BudgetSnapshot.empty(MonthSummary summary) => BudgetSnapshot(
    summary: summary,
    walletSummaries: const <WalletSummary>[],
    expenses: const <Expense>[],
    wallets: const <Wallet>[],
    receipts: const <Receipt>[],
    payments: const <ExpensePayment>[],
  );

  final MonthSummary summary;
  final List<WalletSummary> walletSummaries;
  final List<Expense> expenses;
  final List<Wallet> wallets;
  final List<Receipt> receipts;
  final List<ExpensePayment> payments;
  final List<CreditCard> cards;

  bool get hasWallets => wallets.isNotEmpty;

  double get walletsBalance =>
      walletSummaries.fold(0, (total, summary) => total + summary.balance);

  WalletSummary? summaryFor(int? walletId) {
    if (walletId == null) return null;
    for (final summary in walletSummaries) {
      if (summary.wallet.id == walletId) return summary;
    }
    return null;
  }

  Wallet? walletById(int? id) => summaryFor(id)?.wallet;

  CreditCard? cardById(int? id) {
    if (id == null) return null;
    for (final card in cards) {
      if (card.id == id) return card;
    }
    return null;
  }
}
