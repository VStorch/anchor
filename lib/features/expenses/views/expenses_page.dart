import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/utils/money.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/fab_clearance.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/month_switcher.dart';
import '../../../core/widgets/scroll_aware_fab.dart';
import '../../../core/widgets/stat_tile.dart';
import '../../settings/models/app_tip.dart';
import '../../settings/views/widgets/tip_card.dart';
import '../viewmodels/expenses_view_model.dart';
import 'expense_form_page.dart';
import '../../cards/views/payable_sheet.dart';
import 'widgets/expense_ledger_sheet.dart';
import 'widgets/expense_tile.dart';
import 'widgets/month_table.dart';
import 'widgets/pay_sheet.dart';

class ExpensesPage extends StatelessWidget {
  const ExpensesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<ExpensesViewModel>();

    return ScrollAwareFab(
      heroTag: 'new-expense',
      icon: Icons.add,
      label: 'Nova despesa',
      extended: viewModel.layout == ExpenseLayout.list,
      onPressed: () => ExpenseFormPage.open(
        context,
        referenceMonth: viewModel.month,
        wallets: viewModel.snapshot.wallets,
        cards: viewModel.snapshot.cards,
      ),
      contentKey: (
        viewModel.month,
        viewModel.filter,
        viewModel.layout,
        viewModel.snapshot,
      ),
      builder: (context, fab) => Scaffold(
        appBar: AppBar(
          title: const Text('Despesas'),
          actions: [
            viewModel.layout == ExpenseLayout.table
                ? IconButton(
                    onPressed: () => viewModel.applyLayout(ExpenseLayout.list),
                    icon: const Icon(Icons.view_agenda_outlined),
                    tooltip: 'Ver como lista',
                  )
                : IconButton(
                    onPressed: () => viewModel.applyLayout(ExpenseLayout.table),
                    icon: const Icon(Icons.table_chart_outlined),
                    tooltip: 'Ver como tabela',
                  ),
            const SizedBox(width: 4),
          ],
        ),
        floatingActionButton: fab,
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
                    ? const LoadingView()
                    : viewModel.payables.isEmpty
                    ? _emptyState(context, viewModel)
                    : viewModel.layout == ExpenseLayout.table
                    ? _table(context, viewModel)
                    : _list(context, viewModel),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _list(BuildContext context, ExpensesViewModel viewModel) {
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(16, 8, 16, fabClearance(context)),
      itemCount: viewModel.payables.length + 1,
      separatorBuilder: (_, index) => SizedBox(height: index == 0 ? 0 : 10),
      itemBuilder: (context, index) {
        if (index == 0) return const TipCard(tip: AppTip.expenses);
        final payable = viewModel.payables[index - 1];
        return ExpenseTile(
          payable: payable,
          wallets: viewModel.snapshot.wallets,
          onTap: () => showPayableSheet(context, payable),
        );
      },
    );
  }

  Widget _table(BuildContext context, ExpensesViewModel viewModel) {
    return MonthTable(
      occurrences: viewModel.occurrences,
      onOpen: (occurrence) =>
          ExpenseLedgerSheet.show(context, occurrence: occurrence),
      onAmountChanged: viewModel.setMonthAmount,
      onPaidChanged: (occurrence, amount) async {
        DateTime? paidAt;
        if (occurrence.payments.isEmpty && amount > 0) {
          paidAt = await choosePaidAt(
            context,
            viewModel: viewModel,
            payable: occurrence,
            walletId: viewModel.defaultOriginFor(occurrence).walletId,
          );
          if (paidAt == null) return;
        }
        await viewModel.setPaidAmount(occurrence, amount, paidAt: paidAt);
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
                cards: viewModel.snapshot.cards,
              ),
              icon: const Icon(Icons.add),
              label: const Text('Cadastrar despesa'),
            ),
    );
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

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          for (final filter in ExpenseFilter.values)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(filter.label),
                selected: viewModel.filter == filter,
                onSelected: (_) => viewModel.applyFilter(filter),
              ),
            ),
        ],
      ),
    );
  }
}
