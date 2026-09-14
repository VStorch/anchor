import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/theme/app_palette.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/month.dart';
import '../../../core/widgets/section_header.dart';
import '../models/payout.dart';
import '../models/wallet.dart';
import '../models/wallet_kind.dart';
import '../repositories/wallet_repository.dart';
import '../viewmodels/wallet_form_view_model.dart';
import '../viewmodels/wallets_view_model.dart';
import 'widgets/payout_editor_sheet.dart';

class WalletFormPage extends StatelessWidget {
  const WalletFormPage({super.key, this.wallet, this.suggestedColorIndex = 0});

  static Future<void> open(
    BuildContext context, {
    Wallet? wallet,
    int suggestedColorIndex = 0,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => WalletFormPage(
          wallet: wallet,
          suggestedColorIndex: suggestedColorIndex,
        ),
      ),
    );
  }

  final Wallet? wallet;
  final int suggestedColorIndex;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => WalletFormViewModel(
        repository: context.read<WalletRepository>(),
        wallet: wallet,
        suggestedColorIndex: suggestedColorIndex,
      ),
      child: _WalletFormView(wallet: wallet),
    );
  }
}

class _WalletFormView extends StatelessWidget {
  const _WalletFormView({this.wallet});

  final Wallet? wallet;

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<WalletFormViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: Text(viewModel.isEditing ? 'Editar carteira' : 'Nova carteira'),
        actions: [
          if (wallet != null)
            IconButton(
              onPressed: () => _confirmDelete(context, wallet!),
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Excluir carteira',
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          _KindSelector(viewModel: viewModel),
          const SizedBox(height: 16),
          TextFormField(
            initialValue: viewModel.name,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: 'Nome da carteira',
              hintText: viewModel.kind == WalletKind.salary
                  ? 'Salário, freela...'
                  : 'Vale refeição, vale mercado...',
            ),
            onChanged: viewModel.setName,
          ),
          const SizedBox(height: 20),
          _ColorSelector(viewModel: viewModel),
          const SizedBox(height: 24),
          SectionHeader(
            title: 'Calendário de recebimento',
            subtitle: viewModel.payouts.isEmpty
                ? null
                : '${formatMoney(viewModel.monthlyTotal)} por mês',
            trailing: IconButton.filledTonal(
              onPressed: () => _addPayout(context, viewModel),
              icon: const Icon(Icons.add),
              tooltip: 'Adicionar data',
            ),
          ),
          if (viewModel.payouts.isEmpty)
            const _NoPayoutsHint()
          else
            ...viewModel.payouts.asMap().entries.map(
              (entry) => _PayoutTile(
                payout: entry.value,
                onTap: () => _editPayout(context, viewModel, entry.key),
                onRemove: () => viewModel.removePayoutAt(entry.key),
              ),
            ),
          const SizedBox(height: 28),
          FilledButton(
            onPressed: viewModel.isValid && !viewModel.isSaving
                ? () async {
                    await viewModel.save();
                    if (context.mounted) Navigator.of(context).pop();
                  }
                : null,
            child: Text(
              viewModel.isEditing ? 'Salvar alterações' : 'Criar carteira',
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, Wallet wallet) async {
    final viewModel = context.read<WalletsViewModel>();
    final navigator = Navigator.of(context);

    final paidBills = viewModel.paymentCountOf(wallet);
    final paidNote = switch (paidBills) {
      0 => '',
      1 => '\n\n1 conta paga com ela continua paga, como “Outro dinheiro”.',
      _ =>
        '\n\n$paidBills contas pagas com ela continuam pagas, '
            'como “Outro dinheiro”.',
    };

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Excluir ${wallet.name}?'),
        content: Text(
          'O calendário de recebimentos e todas as entradas dessa carteira '
          'também serão apagados.$paidNote',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmed ?? false) {
      await viewModel.deleteWallet(wallet);
      navigator.pop();
    }
  }

  Future<void> _addPayout(
    BuildContext context,
    WalletFormViewModel viewModel,
  ) async {
    final draft = await PayoutEditorSheet.show(
      context,
      existing: viewModel.payouts,
    );
    if (draft == null) return;

    viewModel.addPayout(
      label: draft.label,
      amount: draft.amount,
      day: draft.day,
      schedule: draft.schedule,
    );
  }

  Future<void> _editPayout(
    BuildContext context,
    WalletFormViewModel viewModel,
    int index,
  ) async {
    final draft = await PayoutEditorSheet.show(
      context,
      existing: viewModel.payouts,
      payout: viewModel.payouts[index],
    );
    if (draft == null) return;

    viewModel.updatePayoutAt(
      index,
      label: draft.label,
      amount: draft.amount,
      day: draft.day,
      schedule: draft.schedule,
    );
  }
}

class _NoPayoutsHint extends StatelessWidget {
  const _NoPayoutsHint();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Text(
      'Use o + para informar em que dias esse dinheiro cai.',
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _KindSelector extends StatelessWidget {
  const _KindSelector({required this.viewModel});

  final WalletFormViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<WalletKind>(
      segments: WalletKind.values
          .map(
            (kind) => ButtonSegment(
              value: kind,
              label: Text(kind.label),
              icon: Icon(
                kind == WalletKind.salary
                    ? Icons.payments_outlined
                    : Icons.card_giftcard_outlined,
              ),
            ),
          )
          .toList(),
      selected: {viewModel.kind},
      onSelectionChanged: (selection) => viewModel.setKind(selection.first),
    );
  }
}

class _ColorSelector extends StatelessWidget {
  const _ColorSelector({required this.viewModel});

  final WalletFormViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: List.generate(AppPalette.wallets.length, (index) {
        final color = AppPalette.walletColorAt(index);
        final isSelected = viewModel.colorIndex == index;

        return GestureDetector(
          onTap: () => viewModel.setColorIndex(index),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: isSelected
                  ? Border.all(
                      color: Theme.of(context).colorScheme.onSurface,
                      width: 3,
                    )
                  : null,
            ),
            child: isSelected
                ? const Icon(Icons.check, color: Colors.white, size: 20)
                : null,
          ),
        );
      }),
    );
  }
}

class _PayoutTile extends StatelessWidget {
  const _PayoutTile({
    required this.payout,
    required this.onTap,
    required this.onRemove,
  });

  final Payout payout;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: ListTile(
          onTap: onTap,
          leading: CircleAvatar(
            backgroundColor: theme.colorScheme.primaryContainer,
            child: Text(
              '${payout.dateIn(Month.current()).day}',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          title: Text(payout.label),
          subtitle: Text(
            '${formatMoney(payout.amount)} · ${payout.scheduleLabel}',
          ),
          trailing: IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.close),
            tooltip: 'Remover',
          ),
        ),
      ),
    );
  }
}
