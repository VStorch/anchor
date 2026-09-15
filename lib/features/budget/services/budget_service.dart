import '../../../core/utils/month.dart';
import '../../cards/repositories/card_repository.dart';
import '../../expenses/repositories/expense_repository.dart';
import '../../wallets/repositories/wallet_repository.dart';
import '../models/budget_snapshot.dart';
import '../models/month_forecast.dart';
import '../models/month_summary.dart';
import '../models/wallet_summary.dart';

class BudgetService {
  BudgetService(
    this._expenseRepository,
    this._walletRepository,
    this._cardRepository, {
    DateTime Function() clock = DateTime.now,
  }) : _clock = clock;

  final ExpenseRepository _expenseRepository;
  final WalletRepository _walletRepository;
  final CardRepository _cardRepository;
  final DateTime Function() _clock;

  Future<BudgetSnapshot> loadSnapshot(Month month, {DateTime? now}) async {
    final today = now ?? _clock();
    final wallets = await _walletRepository.fetchWallets();
    await _walletRepository.registerDuePayouts(wallets, now: today);
    final receipts = await _walletRepository.fetchReceipts();
    final expenses = await _expenseRepository.fetchExpenses();
    final payments = await _expenseRepository.fetchPayments();
    final monthAmounts = await _expenseRepository.fetchMonthAmounts();
    final outflows = await _walletRepository.fetchOutflows();
    final cards = await _cardRepository.fetchCards();
    final checks = await _walletRepository.fetchBalanceChecks();

    MonthSummary summaryOf(Month month) => MonthSummary.build(
      month: month,
      expenses: expenses,
      payments: payments,
      receipts: receipts,
      monthAmounts: monthAmounts,
      outflows: outflows,
      cards: cards,
      today: today,
    );

    final summary = summaryOf(month);
    final walletSummaries = WalletSummary.buildAll(
      month: month,
      wallets: wallets,
      receipts: receipts,
      payments: payments,
      occurrences: summary.occurrences,
      checks: checks,
      outflows: outflows,
    );

    final currentMonth = Month.fromDate(today);
    return BudgetSnapshot(
      summary: summary,
      walletSummaries: walletSummaries,
      forecast: MonthForecast.build(
        month: month,
        today: today,
        walletSummaries: walletSummaries,
        receipts: receipts,
        monthsAhead: [
          for (var ahead = currentMonth; ahead < month; ahead = ahead.next)
            summaryOf(ahead),
          summary,
        ],
      ),
      expenses: expenses,
      wallets: wallets,
      receipts: receipts,
      payments: payments,
      cards: cards,
      checks: checks,
      outflows: outflows,
    );
  }
}
