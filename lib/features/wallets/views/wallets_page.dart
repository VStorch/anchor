import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/utils/money.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/fab_clearance.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/month_switcher.dart';
import '../../../core/widgets/scroll_aware_fab.dart';
import '../../../core/widgets/section_header.dart';
import '../../budget/models/wallet_summary.dart';
import '../../cards/views/card_form_page.dart';
import '../../expenses/views/expense_form_page.dart';
import '../models/spending_source.dart';
import '../models/wallet_kind.dart';
import '../viewmodels/wallets_view_model.dart';
import 'wallet_actions.dart';
import 'wallet_detail_page.dart';
import 'wallet_form_page.dart';
import 'widgets/card_overview_tile.dart';
import 'widgets/spending_source_sheet.dart';
import 'widgets/movement_tile.dart';
import 'widgets/wallet_card.dart';

class WalletsPage extends StatelessWidget {
  const WalletsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<WalletsViewModel>();

    return ScrollAwareFab(
      heroTag: 'new-spending',
      icon: Icons.add,
      label: 'Novo gasto',
      onPressed: () => _newSpending(context, viewModel),
      visible: !viewModel.isLoading && !viewModel.isEmpty,
      contentKey: (viewModel.month, viewModel.summaries),
      builder: (context, fab) => Scaffold(
        appBar: AppBar(title: const Text('Carteiras')),
        floatingActionButton: fab,
        body: viewModel.isLoading
            ? const LoadingView()
            : viewModel.isEmpty
            ? _emptyState(context)
            : _content(context, viewModel),
      ),
    );
  }

  /// With a single wallet and no card there is nothing to ask.
  Future<void> _newSpending(
    BuildContext context,
    WalletsViewModel viewModel,
  ) async {
    if (viewModel.summaries.length == 1 && viewModel.cards.isEmpty) {
      return WalletActions.registerOutflow(
        context,
        viewModel.summaries.single.wallet,
      );
    }

    final source = await SpendingSourceSheet.show(
      context,
      wallets: viewModel.summaries,
      cards: viewModel.cards,
      invoiceMonthOf: viewModel.invoiceMonthForToday,
    );
    if (source == null || !context.mounted) return;

    switch (source) {
      case WalletSource(:final wallet):
        await WalletActions.registerOutflow(context, wallet);
      case CardSource(:final card):
        await Navigator.of(context).push(
          ExpenseFormPage.route(
            referenceMonth: viewModel.month,
            wallets: viewModel.wallets,
            cards: viewModel.cards,
            card: card,
          ),
        );
      case BillSource():
        await Navigator.of(context).push(
          ExpenseFormPage.route(
            referenceMonth: viewModel.month,
            wallets: viewModel.wallets,
            cards: viewModel.cards,
          ),
        );
    }
  }

  Widget _emptyState(BuildContext context) {
    return EmptyState(
      icon: Icons.account_balance_wallet_outlined,
      title: 'Comece pelo dinheiro que entra',
      message: 'Cadastre seu salário e seus benefícios.',
      action: FilledButton.icon(
        onPressed: () => WalletFormPage.open(context),
        icon: const Icon(Icons.add),
        label: const Text('Cadastrar salário ou benefício'),
      ),
    );
  }

  Widget _addWalletButton(
    BuildContext context,
    WalletsViewModel viewModel,
    WalletKind kind,
  ) => IconButton.filledTonal(
    onPressed: () => WalletFormPage.open(
      context,
      suggestedColorIndex: viewModel.summaries.length,
      initialKind: kind,
    ),
    icon: const Icon(Icons.add),
    tooltip: kind == WalletKind.salary
        ? 'Adicionar salário'
        : 'Adicionar benefício',
  );

  Widget _content(BuildContext context, WalletsViewModel viewModel) {
    final salaries = viewModel.summariesOf(WalletKind.salary);
    final benefits = viewModel.summariesOf(WalletKind.benefit);

    return ListView(
      padding: EdgeInsets.fromLTRB(16, 0, 16, fabClearance(context)),
      children: [
        MonthSwitcher(
          month: viewModel.month,
          onPrevious: viewModel.goToPreviousMonth,
          onNext: viewModel.goToNextMonth,
          onToday: viewModel.goToCurrentMonth,
        ),
        const SizedBox(height: 8),
        _TotalBalanceCard(viewModel: viewModel),
        if (salaries.isNotEmpty) ...[
          const SizedBox(height: 20),
          SectionHeader(
            title: 'Salário',
            trailing: _addWalletButton(context, viewModel, WalletKind.salary),
          ),
          ...salaries.map((summary) => _card(context, viewModel, summary)),
        ],
        if (benefits.isNotEmpty) ...[
          const SizedBox(height: 20),
          SectionHeader(
            title: 'Benefícios',
            trailing: _addWalletButton(context, viewModel, WalletKind.benefit),
          ),
          ...benefits.map((summary) => _card(context, viewModel, summary)),
        ] else
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => WalletFormPage.open(
                context,
                suggestedColorIndex: viewModel.summaries.length,
                initialKind: WalletKind.benefit,
              ),
              style: TextButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                alignment: Alignment.centerLeft,
              ),
              icon: const Icon(Icons.add),
              label: const Text('Adicionar VR, VA ou outro benefício'),
            ),
          ),
        const SizedBox(height: 20),
        SectionHeader(
          title: 'Cartões',
          trailing: IconButton.filledTonal(
            onPressed: () => Navigator.of(
              context,
            ).push(CardFormPage.route(wallets: viewModel.wallets)),
            icon: const Icon(Icons.add),
            tooltip: 'Adicionar cartão',
          ),
        ),
        ...viewModel.cardOverview.map(
          (overview) => CardOverviewTile(
            overview: overview,
            month: viewModel.month,
            wallets: viewModel.wallets,
            cards: viewModel.cards,
          ),
        ),
        const SizedBox(height: 20),
        SectionHeader(
          title: 'Movimentações do mês',
          subtitle: viewModel.monthMovements.isEmpty ? 'Nada ainda' : null,
        ),
        ...viewModel.monthMovements.map(
          (movement) => MovementTile(
            movement: movement,
            wallet: viewModel.walletById(movement.walletId),
            onTap: () => WalletActions.openMovement(context, movement),
          ),
        ),
      ],
    );
  }

  Widget _card(
    BuildContext context,
    WalletsViewModel viewModel,
    WalletSummary summary,
  ) {
    final wallet = summary.wallet;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: WalletCard(
        summary: summary,
        month: viewModel.month,
        onTap: () => WalletDetailPage.open(context, walletId: wallet.id!),
        onRegisterReceipt: () => WalletActions.registerReceipt(context, wallet),
        onRegisterOutflow: () => WalletActions.registerOutflow(context, wallet),
        onCheckBalance: () => WalletActions.checkBalance(context, summary),
        onConfirm: WalletActions.confirmFirst(context, wallet),
      ),
    );
  }
}

class _TotalBalanceCard extends StatelessWidget {
  const _TotalBalanceCard({required this.viewModel});

  final WalletsViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Você tem hoje',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              formatMoney(viewModel.totalBalance),
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${formatMoney(viewModel.monthlyIncome)} por mês',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
