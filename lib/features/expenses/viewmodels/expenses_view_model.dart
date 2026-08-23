import '../../../core/state/data_changes.dart';
import '../../../core/state/month_selection.dart';
import '../../../core/utils/month.dart';
import '../../../core/viewmodels/reactive_view_model.dart';
import '../../budget/models/budget_snapshot.dart';
import '../../budget/models/month_summary.dart';
import '../../budget/services/budget_service.dart';
import '../models/expense.dart';
import '../models/expense_occurrence.dart';
import '../models/expense_payment.dart';
import '../repositories/expense_repository.dart';

enum ExpenseFilter {
  all('Todas'),
  pending('A pagar'),
  paid('Pagas');

  const ExpenseFilter(this.label);

  final String label;
}

class ExpensesViewModel extends ReactiveViewModel {
  ExpensesViewModel({
    required BudgetService budgetService,
    required ExpenseRepository expenseRepository,
    required MonthSelection monthSelection,
    required DataChanges changes,
  }) : _budgetService = budgetService,
       _expenseRepository = expenseRepository,
       _monthSelection = monthSelection,
       super(changes) {
    _monthSelection.addListener(refresh);
  }

  final BudgetService _budgetService;
  final ExpenseRepository _expenseRepository;
  final MonthSelection _monthSelection;

  BudgetSnapshot _snapshot = BudgetSnapshot.empty(
    MonthSummary.empty(Month.current()),
  );
  ExpenseFilter _filter = ExpenseFilter.all;

  BudgetSnapshot get snapshot => _snapshot;

  MonthSummary get summary => _snapshot.summary;

  Month get month => _monthSelection.current;

  ExpenseFilter get filter => _filter;

  List<Expense> get registeredExpenses => _snapshot.expenses;

  List<ExpenseOccurrence> get occurrences => switch (_filter) {
    ExpenseFilter.all => summary.occurrences,
    ExpenseFilter.pending => summary.pendingOccurrences,
    ExpenseFilter.paid => summary.paidOccurrences,
  };

  @override
  Future<void> loadData() async {
    _snapshot = await _budgetService.loadSnapshot(_monthSelection.current);
  }

  void applyFilter(ExpenseFilter filter) {
    if (_filter == filter) return;
    _filter = filter;
    safeNotify();
  }

  void goToPreviousMonth() => _monthSelection.goToPrevious();

  void goToNextMonth() => _monthSelection.goToNext();

  Future<void> payOccurrence(
    ExpenseOccurrence occurrence, {
    required int? walletId,
    double? amount,
  }) async {
    await _expenseRepository.savePayment(
      ExpensePayment(
        id: occurrence.payment?.id,
        expenseId: occurrence.expense.id!,
        walletId: walletId,
        month: occurrence.month,
        amount: amount ?? occurrence.expense.amount,
        paidAt: DateTime.now(),
      ),
    );
  }

  Future<void> undoPayment(ExpenseOccurrence occurrence) => _expenseRepository
      .deletePayment(occurrence.expense.id!, occurrence.month);

  Future<void> deleteExpense(Expense expense) =>
      _expenseRepository.deleteExpense(expense.id!);

  Future<void> endRecurringExpense(Expense expense, Month lastMonth) =>
      _expenseRepository.saveExpense(expense.copyWith(endMonth: lastMonth));

  @override
  void dispose() {
    _monthSelection.removeListener(refresh);
    super.dispose();
  }
}
