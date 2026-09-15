import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../app/theme/app_palette.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/section_header.dart';
import '../models/payout.dart';
import '../models/wallet.dart';
import '../models/wallet_deletion_impact.dart';
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

    final lines = _impactLines(viewModel.deletionImpactOf(wallet));

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Excluir ${wallet.name}?'),
        content: Text(
          lines.isEmpty
              ? 'O calendário de recebimentos dessa carteira também será '
                    'apagado.'
              : lines.join('\n\n'),
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

  static List<String> _impactLines(WalletDeletionImpact impact) {
    final removed = [
      if (impact.receipts > 0) _count(impact.receipts, 'entrada', 'entradas'),
      if (impact.outflows > 0) _count(impact.outflows, 'gasto', 'gastos'),
      if (impact.checks > 0)
        _count(impact.checks, 'saldo informado', 'saldos informados'),
    ];
    final removedTotal = impact.receipts + impact.outflows + impact.checks;
    final onlyReceipts = impact.outflows + impact.checks == 0;
    final unassigned = [
      if (impact.plannedBills > 0)
        _count(impact.plannedBills, 'conta', 'contas'),
      if (impact.cards > 0) _count(impact.cards, 'cartão', 'cartões'),
    ];

    return [
      if (removed.isNotEmpty)
        '${_joined(removed)} '
            '${removedTotal == 1 ? 'será' : 'serão'} '
            'apagad${onlyReceipts ? 'a' : 'o'}${removedTotal == 1 ? '' : 's'}.',
      if (impact.paidBills == 1)
        '1 conta paga continua paga, como “Outro dinheiro”.',
      if (impact.paidBills > 1)
        '${impact.paidBills} contas pagas continuam pagas, '
            'como “Outro dinheiro”.',
      if (unassigned.isNotEmpty)
        '${_joined(unassigned)} '
            '${impact.plannedBills + impact.cards == 1 ? 'fica' : 'ficam'} '
            'sem carteira definida.',
    ];
  }

  static String _count(int count, String singular, String plural) =>
      '$count ${count == 1 ? singular : plural}';

  static String _joined(List<String> parts) => parts.length == 1
      ? parts.single
      : '${parts.take(parts.length - 1).join(', ')} e ${parts.last}';

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
            child: Icon(
              Icons.event_repeat,
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
          title: Text(payout.label),
          subtitle: Text(
            '${formatMoney(payout.amount)} · ${payout.scheduleLabel} · '
            '${_nextDateLabel(DateTime.now())}',
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

  String _nextDateLabel(DateTime today) {
    final next = payout.nextDate(today);
    final day = DateFormat(
      'EEE, d/MMM',
      'pt_BR',
    ).format(next).replaceAll('.', '');
    return next.month == today.month ? 'este mês: $day' : 'próximo: $day';
  }
}
