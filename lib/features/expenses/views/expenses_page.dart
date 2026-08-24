import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/utils/money.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/month_switcher.dart';
import '../../../core/widgets/stat_tile.dart';
import '../models/expense_occurrence.dart';
import '../viewmodels/expenses_view_model.dart';
import 'expense_form_page.dart';
import 'widgets/expense_actions_sheet.dart';
import 'widgets/expense_tile.dart';
import 'widgets/pay_expense_sheet.dart';

class ExpensesPage extends StatelessWidget {
  const ExpensesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<ExpensesViewModel>();

    return Scaffold(
      appBar: AppBar(title: const Text('Despesas')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'new-expense',
        onPressed: () => ExpenseFormPage.open(
          context,
          referenceMonth: viewModel.month,
          wallets: viewModel.snapshot.wallets,
        ),
        icon: const Icon(Icons.add),
        label: const Text('Nova despesa'),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: MonthSwitcher(
                month: viewModel.month,
                onPrevious: viewModel.goToPreviousMonth,
                onNext: viewModel.goToNextMonth,
              ),
            ),
            const _MonthTotals(),
            const _FilterBar(),
            Expanded(
              child: viewModel.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : viewModel.occurrences.isEmpty
                  ? _emptyState(context, viewModel)
                  : _list(context, viewModel),
            ),
          ],
        ),
      ),
    );
  }

  Widget _list(BuildContext context, ExpensesViewModel viewModel) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      itemCount: viewModel.occurrences.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final occurrence = viewModel.occurrences[index];
        return ExpenseTile(
          occurrence: occurrence,
          wallet: viewModel.snapshot.walletById(occurrence.walletId),
          onTap: () => _openActions(context, viewModel, occurrence),
          onTogglePaid: () => _togglePaid(context, viewModel, occurrence),
        );
      },
    );
  }

  Widget _emptyState(BuildContext context, ExpensesViewModel viewModel) {
    final hasAny = viewModel.registeredExpenses.isNotEmpty;

    return EmptyState(
      icon: Icons.receipt_long_outlined,
      title: hasAny ? 'Nada neste filtro' : 'Nenhuma despesa cadastrada',
      action: hasAny
          ? null
          : FilledButton.icon(
              onPressed: () => ExpenseFormPage.open(
                context,
                referenceMonth: viewModel.month,
                wallets: viewModel.snapshot.wallets,
              ),
              icon: const Icon(Icons.add),
              label: const Text('Cadastrar despesa'),
            ),
    );
  }

  Future<void> _togglePaid(
    BuildContext context,
    ExpensesViewModel viewModel,
    ExpenseOccurrence occurrence,
  ) async {
    if (occurrence.isPaid) {
      await viewModel.undoPayment(occurrence);
      return;
    }

    final choice = await PayExpenseSheet.show(
      context,
      occurrence: occurrence,
      walletSummaries: viewModel.snapshot.walletSummaries,
    );
    if (choice == null) return;

    await viewModel.payOccurrence(
      occurrence,
      walletId: choice.walletId,
      amount: choice.amount,
    );
  }

  Future<void> _openActions(
    BuildContext context,
    ExpensesViewModel viewModel,
    ExpenseOccurrence occurrence,
  ) async {
    final action = await ExpenseActionsSheet.show(
      context,
      occurrence: occurrence,
    );
    if (action == null || !context.mounted) return;

    switch (action) {
      case ExpenseAction.edit:
        await ExpenseFormPage.open(
          context,
          referenceMonth: viewModel.month,
          wallets: viewModel.snapshot.wallets,
          expense: occurrence.expense,
        );
      case ExpenseAction.undoPayment:
        await viewModel.undoPayment(occurrence);
      case ExpenseAction.endRecurring:
        await viewModel.endRecurringExpense(
          occurrence.expense,
          viewModel.month,
        );
      case ExpenseAction.delete:
        await viewModel.deleteExpense(occurrence.expense);
    }
  }
}

class _MonthTotals extends StatelessWidget {
  const _MonthTotals();

  @override
  Widget build(BuildContext context) {
    final summary = context.watch<ExpensesViewModel>().summary;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Row(
        children: [
          Expanded(
            child: StatTile(
              label: 'Total do mês',
              value: formatMoney(summary.totalExpenses),
              color: theme.colorScheme.onSurface,
              dense: true,
            ),
          ),
          Expanded(
            child: StatTile(
              label: 'Pago',
              value: formatMoney(summary.totalPaid),
              color: theme.colorScheme.primary,
              dense: true,
            ),
          ),
          Expanded(
            child: StatTile(
              label: 'Falta pagar',
              value: formatMoney(summary.totalPending),
              color: summary.totalPending > 0
                  ? theme.colorScheme.error
                  : theme.colorScheme.primary,
              dense: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar();

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<ExpensesViewModel>();

    return SizedBox(
      height: 56,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: ExpenseFilter.values
            .map(
              (filter) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(filter.label),
                  selected: viewModel.filter == filter,
                  onSelected: (_) => viewModel.applyFilter(filter),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}
