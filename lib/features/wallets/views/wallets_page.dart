import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/utils/money.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/month_switcher.dart';
import '../../../core/widgets/section_header.dart';
import '../../budget/models/wallet_summary.dart';
import '../models/receipt.dart';
import '../models/wallet.dart';
import '../models/wallet_kind.dart';
import '../viewmodels/wallets_view_model.dart';
import 'wallet_form_page.dart';
import 'widgets/manual_receipt_sheet.dart';
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
          ? const Center(child: CircularProgressIndicator())
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
          title: 'Entradas do mês',
          subtitle: viewModel.monthReceipts.isEmpty ? 'Nada ainda' : null,
        ),
        ...viewModel.monthReceipts.map(
          (receipt) => _ReceiptTile(
            receipt: receipt,
            wallet: viewModel.walletById(receipt.walletId),
            onDelete: () => viewModel.deleteReceipt(receipt),
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
      ),
    );
  }

  Future<void> _registerReceipt(BuildContext context, Wallet wallet) async {
    final viewModel = context.read<WalletsViewModel>();
    final receipt = await ManualReceiptSheet.show(context, wallet: wallet);
    if (receipt == null) return;

    await viewModel.registerReceipt(
      wallet: wallet,
      amount: receipt.amount,
      receivedAt: receipt.receivedAt,
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

class _ReceiptTile extends StatelessWidget {
  const _ReceiptTile({
    required this.receipt,
    required this.wallet,
    required this.onDelete,
  });

  final Receipt receipt;
  final Wallet? wallet;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: (wallet?.color ?? theme.colorScheme.primary)
            .withValues(alpha: 0.16),
        child: Icon(
          Icons.arrow_downward,
          size: 18,
          color: wallet?.color ?? theme.colorScheme.primary,
        ),
      ),
      title: Text(wallet?.name ?? 'Carteira removida'),
      subtitle: Text(
        '${DateFormat.yMMMMd('pt_BR').format(receipt.receivedAt)}'
        '${receipt.isManual ? ' · manual' : ''}',
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            formatMoney(receipt.amount),
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.primary,
            ),
          ),
          if (receipt.isManual)
            IconButton(
              onPressed: onDelete,
              icon: const Icon(Icons.close, size: 18),
              tooltip: 'Remover entrada',
            ),
        ],
      ),
    );
  }
}
