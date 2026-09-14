import '../../../core/state/data_changes.dart';
import '../../../core/state/month_selection.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/month.dart';
import '../../../core/viewmodels/reactive_view_model.dart';
import '../../budget/models/budget_snapshot.dart';
import '../../budget/models/month_summary.dart';
import '../../budget/services/budget_service.dart';
import '../../cards/models/card_invoice.dart';
import '../models/expense.dart';
import '../models/expense_month.dart';
import '../models/expense_occurrence.dart';
import '../models/expense_payment.dart';
import '../models/payable.dart';
import '../repositories/expense_repository.dart';

enum ExpenseFilter {
  all('Todas'),
  pending('A pagar'),
  paid('Pagas');

  const ExpenseFilter(this.label);

  final String label;
}

enum ExpenseLayout { list, table }

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
  ExpenseLayout _layout = ExpenseLayout.list;

  BudgetSnapshot get snapshot => _snapshot;

  MonthSummary get summary => _snapshot.summary;

  Month get month => _monthSelection.current;

  ExpenseFilter get filter => _filter;

  ExpenseLayout get layout => _layout;

  List<Expense> get registeredExpenses => _snapshot.expenses;

  List<Payable> get payables => switch (_filter) {
    ExpenseFilter.all => summary.payables,
    ExpenseFilter.pending => summary.pendingPayables,
    ExpenseFilter.paid => summary.paidPayables,
  };

  List<ExpenseOccurrence> get occurrences => switch (_filter) {
    ExpenseFilter.all => summary.occurrences,
    ExpenseFilter.pending => summary.pendingOccurrences,
    ExpenseFilter.paid => summary.paidOccurrences,
  };

  CardInvoice? invoiceOf(int cardId) => summary.invoiceOf(cardId);

  @override
  Future<void> loadData() async {
    _snapshot = await _budgetService.loadSnapshot(_monthSelection.current);
  }

  void applyFilter(ExpenseFilter filter) {
    if (_filter == filter) return;
    _filter = filter;
    safeNotify();
  }

  void applyLayout(ExpenseLayout layout) {
    if (_layout == layout) return;
    _layout = layout;
    safeNotify();
  }

  void goToPreviousMonth() => _monthSelection.goToPrevious();

  void goToNextMonth() => _monthSelection.goToNext();

  ExpenseOccurrence? occurrenceOf(int expenseId) =>
      summary.occurrenceOf(expenseId);

  Future<void> savePaymentLine(
    ExpenseOccurrence occurrence, {
    int? id,
    required int? walletId,
    required double amount,
  }) => _expenseRepository.savePayment(
    ExpensePayment(
      id: id,
      expenseId: occurrence.expense.id!,
      walletId: walletId,
      month: occurrence.month,
      amount: amount,
      paidAt: DateTime.now(),
    ),
  );

  Future<void> settle(
    ExpenseOccurrence occurrence, {
    required int? walletId,
  }) async {
    if (occurrence.remaining <= 0) return;
    await savePaymentLine(
      occurrence,
      walletId: walletId,
      amount: occurrence.remaining,
    );
  }

  Future<void> setPaidAmount(
    ExpenseOccurrence occurrence,
    double amount,
  ) async {
    if (sameAmount(amount, occurrence.paidAmount)) return;
    if (amount <= 0) return clearPayments(occurrence);

    final existing = occurrence.payments;
    if (existing.length > 1) return;

    await savePaymentLine(
      occurrence,
      id: existing.isEmpty ? null : existing.single.id,
      walletId: existing.isEmpty
          ? defaultWalletIdFor(occurrence)
          : existing.single.walletId ?? defaultWalletIdFor(occurrence),
      amount: amount,
    );
  }

  int? defaultWalletIdFor(ExpenseOccurrence occurrence) {
    final planned = occurrence.plannedWalletId;
    if (_snapshot.walletById(planned) != null) return planned;
    return _snapshot.wallets.isEmpty ? null : _snapshot.wallets.first.id;
  }

  int? defaultWalletIdForInvoice(CardInvoice invoice) {
    final planned = invoice.card.walletId;
    if (_snapshot.walletById(planned) != null) return planned;
    return _snapshot.wallets.isEmpty ? null : _snapshot.wallets.first.id;
  }

  Future<void> payInvoice(CardInvoice invoice, {required int? walletId}) =>
      _expenseRepository.savePayments([
        for (final (item, amount) in invoice.settlement)
          ExpensePayment(
            expenseId: item.expense.id!,
            walletId: walletId,
            month: item.month,
            amount: amount,
            paidAt: DateTime.now(),
          ),
      ]);

  Future<void> clearInvoicePayments(CardInvoice invoice) =>
      _expenseRepository.deletePaymentsOfMany(
        invoice.items.map((item) => item.expense.id!).toList(),
        invoice.month,
      );

  Future<void> removePayment(ExpensePayment payment) =>
      _expenseRepository.deletePayment(payment.id!);

  Future<void> clearPayments(ExpenseOccurrence occurrence) => _expenseRepository
      .deletePaymentsOf(occurrence.expense.id!, occurrence.month);

  /// A blank amount means "back to the rule", and leaving the field untouched
  /// writes nothing — otherwise the month would freeze the rule's value.
  Future<void> setMonthAmount(
    ExpenseOccurrence occurrence,
    double amount,
  ) async {
    if (amount <= 0) return resetMonthAmount(occurrence);
    if (sameAmount(amount, occurrence.amount)) return;
    await _expenseRepository.saveMonthAmount(
      ExpenseMonth(
        expenseId: occurrence.expense.id!,
        month: occurrence.month,
        amount: amount,
      ),
    );
  }

  Future<void> resetMonthAmount(ExpenseOccurrence occurrence) async {
    if (!occurrence.hasCustomAmount) return;
    await _expenseRepository.clearMonthAmount(
      occurrence.expense.id!,
      occurrence.month,
    );
  }

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
