import '../../../core/utils/moment.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/month.dart';
import '../../cards/models/credit_card.dart';
import '../../expenses/models/expense.dart';
import '../../expenses/models/expense_payment.dart';
import '../../wallets/models/balance_check.dart';
import '../../wallets/models/receipt.dart';
import '../../wallets/models/wallet.dart';
import 'month_forecast.dart';
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
    this.checks = const <BalanceCheck>[],
    this.forecast,
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
  final List<BalanceCheck> checks;
  final MonthForecast? forecast;

  bool get hasWallets => wallets.isNotEmpty;

  List<ExpensePayment> paymentsOf(int expenseId) =>
      payments.where((payment) => payment.expenseId == expenseId).toList();

  double totalPaidOf(int expenseId) => roundCents(
    paymentsOf(expenseId).fold(0, (total, payment) => total + payment.amount),
  );

  /// How many bills (expense and month) were paid, at least in part, with
  /// the wallet.
  int paymentCountOf(int walletId) => payments
      .where((payment) => payment.walletId == walletId)
      .map((payment) => (payment.expenseId, payment.month))
      .toSet()
      .length;

  double get walletsBalance => roundCents(
    walletSummaries.fold(0, (total, summary) => total + summary.balance),
  );

  /// What the calendar says already came in this month and still waits for
  /// the user to confirm, whatever month is on screen.
  double get awaitingConfirmation {
    final currentMonth = Month.fromDate(summary.today);
    return roundCents(
      receipts
          .where((receipt) => receipt.isPredicted)
          .where((receipt) => receipt.month == currentMonth)
          .fold(0, (total, receipt) => total + receipt.amount),
    );
  }

  WalletSummary? summaryFor(int? walletId) {
    if (walletId == null) return null;
    for (final summary in walletSummaries) {
      if (summary.wallet.id == walletId) return summary;
    }
    return null;
  }

  Wallet? walletById(int? id) => summaryFor(id)?.wallet;

  BalanceCheck? latestCheckOf(int walletId) =>
      summaryFor(walletId)?.latestCheck;

  BalanceCheck? checkOnDay(int walletId, DateTime day) {
    BalanceCheck? found;
    for (final check in checks) {
      if (check.walletId == walletId && isSameDay(check.checkedAt, day)) {
        found = check;
      }
    }
    return found;
  }

  CreditCard? cardById(int? id) {
    if (id == null) return null;
    for (final card in cards) {
      if (card.id == id) return card;
    }
    return null;
  }
}
