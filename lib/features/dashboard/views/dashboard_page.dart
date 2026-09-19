import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/app_shell.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/month.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/fab_clearance.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/month_switcher.dart';
import '../../../core/widgets/scroll_aware_fab.dart';
import '../../../core/widgets/section_header.dart';
import '../../expenses/views/widgets/expense_tile.dart';
import '../../cards/views/payable_sheet.dart';
import '../../settings/models/app_tip.dart';
import '../../settings/views/widgets/tip_card.dart';
import '../../wallets/views/wallet_actions.dart';
import '../../wallets/views/wallet_form_page.dart';
import '../../budget/models/month_summary.dart';
import '../../wallets/models/wallet.dart';
import '../viewmodels/dashboard_view_model.dart';
import 'month_agenda_page.dart';
import 'widgets/daily_spending_sheet.dart';
import 'widgets/forecast_card.dart';
import 'widgets/month_so_far_card.dart';
import 'widgets/today_card.dart';
import 'widgets/wallet_strip.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  static const int _upcomingLimit = 4;

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<DashboardViewModel>();

    return ScrollAwareFab(
      heroTag: 'dashboard-new-spending',
      icon: Icons.add,
      label: 'Novo gasto',
      onPressed: () => WalletActions.newSpending(context),
      visible: !viewModel.isLoading && !viewModel.needsSetup,
      contentKey: (viewModel.month, viewModel.snapshot),
      builder: (context, fab) => Scaffold(
        appBar: AppBar(
          title: const Text('Anchor'),
          actions: [
            IconButton(
              onPressed: () => MonthAgendaPage.open(context),
              icon: const Icon(Icons.calendar_month_outlined),
              tooltip: 'Agenda do mês',
            ),
          ],
        ),
        floatingActionButton: fab,
        body: viewModel.isLoading
            ? const LoadingView()
            : viewModel.needsSetup
            ? _onboarding(context)
            : _content(context, viewModel),
      ),
    );
  }

  Widget _onboarding(BuildContext context) {
    return EmptyState(
      icon: Icons.anchor_outlined,
      title: 'Vamos ancorar seu mês',
      action: FilledButton.icon(
        onPressed: () => WalletFormPage.open(context),
        icon: const Icon(Icons.add),
        label: const Text('Cadastrar meu salário'),
      ),
    );
  }

  Future<void> _editReserve(
    BuildContext context,
    DashboardViewModel viewModel,
    Wallet? editing,
  ) async {
    final salaries = viewModel.salaries;
    if (salaries.isEmpty) return;

    final edit = await DailySpendingSheet.show(
      context,
      salaries: salaries,
      averageOf: viewModel.outflowAverageOf,
      initial: salaries.where((wallet) => wallet.id == editing?.id).firstOrNull,
    );
    if (edit == null) return;

    await viewModel.saveReserve(edit.wallet, edit.amount);
  }

  Widget _content(BuildContext context, DashboardViewModel viewModel) {
    final snapshot = viewModel.snapshot;
    final summary = viewModel.summary;
    final forecast = snapshot.forecast;
    final upcoming = summary.pendingPayables.take(_upcomingLimit).toList();
    final showsMonthSoFar = summary.month <= Month.fromDate(summary.today);

    return RefreshIndicator(
      onRefresh: viewModel.refresh,
      child: ListView(
        padding: EdgeInsets.fromLTRB(16, 0, 16, fabClearance(context)),
        children: [
          const TipCard(tip: AppTip.dashboard),
          TodayCard(
            balance: snapshot.walletsBalance,
            wallets: snapshot.walletSummaries,
            awaitingConfirmation: snapshot.awaitingConfirmation,
            onConfirm: () {
              viewModel.goToCurrentMonth();
              context.read<AppShellController>().goTo(
                AppShellController.walletsTab,
              );
            },
          ),
          const SizedBox(height: 8),
          MonthSwitcher(
            month: viewModel.month,
            onPrevious: viewModel.goToPreviousMonth,
            onNext: viewModel.goToNextMonth,
            onToday: viewModel.goToCurrentMonth,
          ),
          const SizedBox(height: 8),
          if (forecast != null) ...[
            ForecastCard(
              forecast: forecast,
              onEditReserve: (wallet) =>
                  _editReserve(context, viewModel, wallet),
            ),
            const SizedBox(height: 12),
          ],
          if (showsMonthSoFar)
            MonthSoFarCard(
              summary: summary,
              reconciliation: snapshot.reconciliation,
            ),
          const SizedBox(height: 20),
          SectionHeader(
            title: 'Carteiras',
            trailing: TextButton(
              onPressed: () => context.read<AppShellController>().goTo(
                AppShellController.walletsTab,
              ),
              child: const Text('Gerenciar'),
            ),
          ),
          WalletStrip(
            summaries: viewModel.snapshot.walletSummaries,
            onTap: () => context.read<AppShellController>().goTo(
              AppShellController.walletsTab,
            ),
          ),
          const SizedBox(height: 20),
          SectionHeader(
            title: 'A pagar',
            subtitle: _pendingLine(summary),
            trailing: TextButton(
              onPressed: () => context.read<AppShellController>().goTo(
                AppShellController.expensesTab,
              ),
              child: const Text('Ver todas'),
            ),
          ),
          if (upcoming.isEmpty)
            const _AllSettledCard()
          else
            ...upcoming.map(
              (payable) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: ExpenseTile(
                  payable: payable,
                  wallets: viewModel.snapshot.wallets,
                  onTap: () => showPayableSheet(context, payable),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

String? _pendingLine(MonthSummary summary) {
  final overdue = summary.overduePayables.length;
  final dueToday = summary.dueTodayPayables.length;
  final parts = [
    if (overdue > 0) '$overdue em atraso',
    if (dueToday > 0) '$dueToday vence${dueToday > 1 ? 'm' : ''} hoje',
    if (summary.totalPending > 0)
      '${formatMoney(summary.totalPending)} a pagar',
  ];
  return parts.isEmpty ? null : parts.join(' · ');
}

class _AllSettledCard extends StatelessWidget {
  const _AllSettledCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      color: theme.colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(
              Icons.check_circle_outline,
              color: theme.colorScheme.onSecondaryContainer,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Nada a pagar neste mês.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSecondaryContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
