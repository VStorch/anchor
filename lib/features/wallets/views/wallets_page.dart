import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/utils/money.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/month_switcher.dart';
import '../../../core/widgets/section_header.dart';
import '../../budget/models/wallet_summary.dart';
import '../models/outflow.dart';
import '../models/receipt.dart';
import '../models/wallet.dart';
import '../models/wallet_kind.dart';
import '../models/wallet_movement.dart';
import '../viewmodels/wallets_view_model.dart';
import 'wallet_form_page.dart';
import 'widgets/balance_adjustment_sheet.dart';
import 'widgets/outflow_sheet.dart';
import 'widgets/receipt_sheet.dart';
import 'widgets/wallet_card.dart';

class WalletsPage extends StatelessWidget {
  const WalletsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<WalletsViewModel>();

    return Scaffold(
      appBar: AppBar(title: const Text('Carteiras')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'new-wallet',
        onPressed: () => WalletFormPage.open(
          context,
          suggestedColorIndex: viewModel.summaries.length,
        ),
        icon: const Icon(Icons.add),
        label: const Text('Nova carteira'),
      ),
      body: viewModel.isLoading
          ? const LoadingView()
          : viewModel.isEmpty
          ? _emptyState(context)
          : _content(context, viewModel),
    );
  }

  Widget _emptyState(BuildContext context) {
    return EmptyState(
      icon: Icons.account_balance_wallet_outlined,
      title: 'Comece pelo dinheiro que entra',
      message: 'Cadastre seu salário e seus benefícios.',
      action: FilledButton.icon(
        onPressed: () => WalletFormPage.open(context),
        icon: const Icon(Icons.add),
        label: const Text('Criar carteira'),
      ),
    );
  }

  Widget _content(BuildContext context, WalletsViewModel viewModel) {
    final salaries = viewModel.summariesOf(WalletKind.salary);
    final benefits = viewModel.summariesOf(WalletKind.benefit);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
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
          const SectionHeader(title: 'Salário'),
          ...salaries.map((summary) => _card(context, summary)),
        ],
        if (benefits.isNotEmpty) ...[
          const SizedBox(height: 20),
          const SectionHeader(title: 'Benefícios'),
          ...benefits.map((summary) => _card(context, summary)),
        ],
        const SizedBox(height: 20),
        SectionHeader(
          title: 'Movimentações do mês',
          subtitle: viewModel.monthMovements.isEmpty ? 'Nada ainda' : null,
        ),
        ...viewModel.monthMovements.map(
          (movement) => _MovementTile(
            movement: movement,
            wallet: viewModel.walletById(movement.walletId),
            onTap: () => _openMovement(context, movement),
          ),
        ),
      ],
    );
  }

  Widget _card(BuildContext context, WalletSummary summary) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: WalletCard(
        summary: summary,
        onTap: () => WalletFormPage.open(context, wallet: summary.wallet),
        onRegisterReceipt: () => _registerReceipt(context, summary.wallet),
        onRegisterOutflow: () => _registerOutflow(context, summary.wallet),
        onAdjustBalance: () => _adjustBalance(context, summary),
      ),
    );
  }

  Future<void> _registerReceipt(BuildContext context, Wallet wallet) async {
    final viewModel = context.read<WalletsViewModel>();
    final edit = await ReceiptSheet.show(context, wallet: wallet);
    if (edit == null || edit.isDiscarded) return;

    await viewModel.registerReceipt(
      wallet: wallet,
      amount: edit.amount,
      receivedAt: edit.receivedAt,
    );
  }

  Future<void> _registerOutflow(BuildContext context, Wallet wallet) async {
    final viewModel = context.read<WalletsViewModel>();
    final edit = await OutflowSheet.show(context, wallet: wallet);
    if (edit == null || edit.isDiscarded) return;

    await viewModel.saveOutflow(
      wallet: wallet,
      description: edit.description,
      amount: edit.amount,
      spentAt: edit.spentAt,
    );
  }

  Future<void> _adjustBalance(
    BuildContext context,
    WalletSummary summary,
  ) async {
    final viewModel = context.read<WalletsViewModel>();
    final balance = await BalanceAdjustmentSheet.show(
      context,
      wallet: summary.wallet,
      currentBalance: summary.balance,
    );
    if (balance == null) return;

    await viewModel.adjustBalance(summary, balance);
  }

  Future<void> _openMovement(
    BuildContext context,
    WalletMovement movement,
  ) async {
    final receipt = movement.receipt;
    final outflow = movement.outflow;

    if (receipt != null) return _editReceipt(context, receipt);
    if (outflow != null) return _editOutflow(context, outflow);
  }

  Future<void> _editOutflow(BuildContext context, Outflow outflow) async {
    final viewModel = context.read<WalletsViewModel>();
    final wallet = viewModel.walletById(outflow.walletId);
    if (wallet == null) return;

    final edit = await OutflowSheet.show(
      context,
      wallet: wallet,
      outflow: outflow,
    );
    if (edit == null) return;

    if (edit.isDiscarded) {
      await viewModel.deleteOutflow(outflow);
      return;
    }

    await viewModel.saveOutflow(
      wallet: wallet,
      outflow: outflow,
      description: edit.description,
      amount: edit.amount,
      spentAt: edit.spentAt,
    );
  }

  Future<void> _editReceipt(BuildContext context, Receipt receipt) async {
    final viewModel = context.read<WalletsViewModel>();
    final wallet = viewModel.walletById(receipt.walletId);
    if (wallet == null) return;

    final edit = await ReceiptSheet.show(
      context,
      wallet: wallet,
      receipt: receipt,
    );
    if (edit == null) return;

    if (edit.isDiscarded) {
      await viewModel.discardReceipt(receipt);
      return;
    }

    await viewModel.confirmReceipt(
      receipt,
      amount: edit.amount,
      receivedAt: edit.receivedAt,
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
              'Saldo total',
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

class _MovementTile extends StatelessWidget {
  const _MovementTile({
    required this.movement,
    required this.wallet,
    required this.onTap,
  });

  final WalletMovement movement;
  final Wallet? wallet;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = wallet?.color ?? theme.colorScheme.primary;
    final amountColor = movement.isPredicted
        ? theme.colorScheme.onSurfaceVariant
        : movement.isIncome
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurface;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: movement.isEditable ? onTap : null,
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.16),
        child: Icon(_icon, size: 18, color: color),
      ),
      title: Text(movement.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${DateFormat.MMMd('pt_BR').format(movement.date)}'
        ' · ${wallet?.name ?? 'Carteira removida'}'
        '${movement.isPredicted ? ' · a confirmar' : ''}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Text(
        '${movement.amount > 0
            ? '+'
            : movement.amount < 0
            ? '−'
            : ''}'
        '${formatMoney(movement.amount.abs())}',
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: amountColor,
        ),
      ),
    );
  }

  IconData get _icon {
    if (movement.isAdjustment) return Icons.tune;
    if (movement.isPredicted) return Icons.schedule;
    if (movement.isIncome) return Icons.arrow_downward;
    if (movement.outflow != null) return Icons.shopping_bag_outlined;
    return Icons.arrow_upward;
  }
}
