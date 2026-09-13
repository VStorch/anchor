import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/app_shell.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/month_switcher.dart';
import '../../../core/widgets/section_header.dart';
import '../../expenses/views/widgets/expense_tile.dart';
import '../../expenses/views/widgets/expense_ledger_sheet.dart';
import '../../wallets/views/wallet_form_page.dart';
import '../viewmodels/dashboard_view_model.dart';
import 'month_agenda_page.dart';
import 'widgets/balance_card.dart';
import 'widgets/wallet_strip.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  static const int _upcomingLimit = 4;

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<DashboardViewModel>();

    return Scaffold(
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
      body: viewModel.isLoading
          ? const LoadingView()
          : viewModel.needsSetup
          ? _onboarding(context)
          : _content(context, viewModel),
    );
  }

  Widget _onboarding(BuildContext context) {
    return EmptyState(
      icon: Icons.anchor_outlined,
      title: 'Vamos ancorar seu mês',
      message:
          'Cadastre de onde vem o seu dinheiro e o saldo se atualiza a cada pagamento.',
      action: FilledButton.icon(
        onPressed: () => WalletFormPage.open(context),
        icon: const Icon(Icons.add),
        label: const Text('Cadastrar meu salário'),
      ),
    );
  }

  Widget _content(BuildContext context, DashboardViewModel viewModel) {
    final summary = viewModel.summary;
    final upcoming = summary.pendingOccurrences.take(_upcomingLimit).toList();

    return RefreshIndicator(
      onRefresh: viewModel.refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          MonthSwitcher(
            month: viewModel.month,
            onPrevious: viewModel.goToPreviousMonth,
            onNext: viewModel.goToNextMonth,
            onToday: viewModel.goToCurrentMonth,
          ),
          const SizedBox(height: 12),
          BalanceCard(snapshot: viewModel.snapshot),
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
            subtitle: summary.overdueOccurrences.isNotEmpty
                ? '${summary.overdueOccurrences.length} em atraso'
                : null,
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
              (occurrence) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: ExpenseTile(
                  occurrence: occurrence,
                  wallets: viewModel.snapshot.wallets,
                  onTap: () =>
                      ExpenseLedgerSheet.show(context, occurrence: occurrence),
                ),
              ),
            ),
        ],
      ),
    );
  }
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
