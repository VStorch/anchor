import '../../../core/utils/month.dart';
import '../../expenses/repositories/expense_repository.dart';
import '../../wallets/repositories/wallet_repository.dart';
import '../models/budget_snapshot.dart';
import '../models/month_summary.dart';
import '../models/wallet_summary.dart';

class BudgetService {
  BudgetService(this._expenseRepository, this._walletRepository);

  final ExpenseRepository _expenseRepository;
  final WalletRepository _walletRepository;

  Future<BudgetSnapshot> loadSnapshot(Month month) async {
    final wallets = await _walletRepository.fetchWallets();
    await _walletRepository.registerDuePayouts(wallets);
    final receipts = await _walletRepository.fetchReceipts();
    final expenses = await _expenseRepository.fetchExpenses();
    final payments = await _expenseRepository.fetchPayments();
    final monthAmounts = await _expenseRepository.fetchMonthAmounts();
    final outflows = await _walletRepository.fetchOutflows();

    final summary = MonthSummary.build(
      month: month,
      expenses: expenses,
      payments: payments,
      receipts: receipts,
      monthAmounts: monthAmounts,
      outflows: outflows,
    );

    return BudgetSnapshot(
      summary: summary,
      walletSummaries: WalletSummary.buildAll(
        month: month,
        wallets: wallets,
        receipts: receipts,
        payments: payments,
        occurrences: summary.occurrences,
        outflows: outflows,
      ),
      expenses: expenses,
      wallets: wallets,
      receipts: receipts,
      payments: payments,
    );
  }
}
