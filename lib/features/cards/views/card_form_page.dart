import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/day_of_month_picker.dart';
import '../../wallets/models/wallet.dart';
import '../../wallets/models/wallet_kind.dart';
import '../models/credit_card.dart';
import '../repositories/card_repository.dart';
import '../viewmodels/card_form_view_model.dart';

class CardFormPage extends StatelessWidget {
  const CardFormPage({super.key, required this.wallets, this.card});

  /// Pops with `true` when the card was deleted, so whatever showed its
  /// invoice can close too.
  static MaterialPageRoute<bool> route({
    required List<Wallet> wallets,
    CreditCard? card,
  }) => MaterialPageRoute<bool>(
    builder: (_) => CardFormPage(wallets: wallets, card: card),
  );

  final List<Wallet> wallets;
  final CreditCard? card;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => CardFormViewModel(
        repository: context.read<CardRepository>(),
        card: card,
        likelyWalletId: _likelyWalletId(),
      ),
      child: _CardFormView(wallets: wallets),
    );
  }

  int? _likelyWalletId() {
    for (final wallet in wallets) {
      if (wallet.kind == WalletKind.salary) return wallet.id;
    }
    return wallets.isEmpty ? null : wallets.first.id;
  }
}

class _CardFormView extends StatelessWidget {
  const _CardFormView({required this.wallets});

  final List<Wallet> wallets;

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<CardFormViewModel>();
    final titleStyle = Theme.of(
      context,
    ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700);

    return Scaffold(
      appBar: AppBar(
        title: Text(viewModel.isEditing ? 'Editar cartão' : 'Novo cartão'),
        actions: [
          if (viewModel.isEditing)
            IconButton(
              onPressed: () => _confirmDelete(context, viewModel),
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Excluir cartão',
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          TextFormField(
            initialValue: viewModel.name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Nome do cartão'),
            onChanged: viewModel.setName,
          ),
          const SizedBox(height: 24),
          Text('Fecha no dia', style: titleStyle),
          const SizedBox(height: 12),
          DayOfMonthPicker(
            selectedDay: viewModel.closingDay,
            onDaySelected: viewModel.setClosingDay,
          ),
          const SizedBox(height: 24),
          Text('Vence no dia', style: titleStyle),
          const SizedBox(height: 12),
          DayOfMonthPicker(
            selectedDay: viewModel.dueDay,
            onDaySelected: viewModel.setDueDay,
          ),
          if (wallets.isNotEmpty) ...[
            const SizedBox(height: 24),
            DropdownButtonFormField<int?>(
              value: viewModel.walletId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Fatura paga com'),
              items: [
                for (final wallet in wallets)
                  DropdownMenuItem<int?>(
                    value: wallet.id,
                    child: Row(
                      children: [
                        Icon(wallet.icon, size: 18, color: wallet.color),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            wallet.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
              onChanged: viewModel.setWalletId,
            ),
          ],
          const SizedBox(height: 28),
          FilledButton(
            onPressed: viewModel.isValid && !viewModel.isSaving
                ? () async {
                    await viewModel.save();
                    if (context.mounted) Navigator.of(context).pop();
                  }
                : null,
            child: Text(
              viewModel.missingDay ??
                  (viewModel.isEditing ? 'Salvar alterações' : 'Criar cartão'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    CardFormViewModel viewModel,
  ) async {
    final navigator = Navigator.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Excluir ${viewModel.name}?'),
        content: const Text('As compras continuam, como despesas soltas.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await viewModel.delete();
    navigator.pop(true);
  }
}
