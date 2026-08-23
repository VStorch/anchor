import '../../../core/state/data_changes.dart';
import '../../../core/state/month_selection.dart';
import '../../../core/utils/month.dart';
import '../../../core/viewmodels/reactive_view_model.dart';
import '../../budget/models/budget_snapshot.dart';
import '../../budget/models/month_summary.dart';
import '../../budget/services/budget_service.dart';

class DashboardViewModel extends ReactiveViewModel {
  DashboardViewModel({
    required BudgetService budgetService,
    required MonthSelection monthSelection,
    required DataChanges changes,
  }) : _budgetService = budgetService,
       _monthSelection = monthSelection,
       super(changes) {
    _monthSelection.addListener(refresh);
  }

  final BudgetService _budgetService;
  final MonthSelection _monthSelection;

  BudgetSnapshot _snapshot = BudgetSnapshot.empty(
    MonthSummary.empty(Month.current()),
  );

  BudgetSnapshot get snapshot => _snapshot;

  MonthSummary get summary => _snapshot.summary;

  Month get month => _monthSelection.current;

  bool get isCurrentMonth => _monthSelection.isCurrentMonth;

  bool get needsSetup => !_snapshot.hasWallets;

  @override
  Future<void> loadData() async {
    _snapshot = await _budgetService.loadSnapshot(_monthSelection.current);
  }

  void goToPreviousMonth() => _monthSelection.goToPrevious();

  void goToNextMonth() => _monthSelection.goToNext();

  void goToCurrentMonth() => _monthSelection.goToToday();

  @override
  void dispose() {
    _monthSelection.removeListener(refresh);
    super.dispose();
  }
}
