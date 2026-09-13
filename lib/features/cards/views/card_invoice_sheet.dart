import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/utils/money.dart';
import '../../expenses/models/expense_occurrence.dart';
import '../../expenses/viewmodels/expenses_view_model.dart';
import '../../expenses/views/expense_form_page.dart';
import '../../expenses/views/widgets/expense_ledger_sheet.dart';
import '../models/card_invoice.dart';
import 'card_form_page.dart';

class CardInvoiceSheet extends StatelessWidget {
  const CardInvoiceSheet({super.key, required this.cardId});

  static Future<void> show(BuildContext context, {required int cardId}) {
    final viewModel = context.read<ExpensesViewModel>();

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => ChangeNotifierProvider<ExpensesViewModel>.value(
        value: viewModel,
        child: CardInvoiceSheet(cardId: cardId),
      ),
    );
  }

  final int cardId;

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<ExpensesViewModel>();
    final invoice = viewModel.invoiceOf(cardId);
    if (invoice == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final card = invoice.card;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    invoice.name,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () async {
                    final navigator = Navigator.of(context);
                    final deleted = await navigator.push(
                      CardFormPage.route(
                        wallets: viewModel.snapshot.wallets,
                        card: card,
                      ),
                    );
                    if (deleted ?? false) navigator.pop();
                  },
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: 'Editar cartão',
                ),
              ],
            ),
            Text(
              'Vence em ${DateFormat.MMMMd('pt_BR').format(invoice.dueDate)}'
              ' · fecha dia ${card.closingDay}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            ...invoice.items.map((item) => _ItemLine(item: item)),
            TextButton.icon(
              onPressed: () => Navigator.of(context).push(
                ExpenseFormPage.route(
                  referenceMonth: viewModel.month,
                  wallets: viewModel.snapshot.wallets,
                  cards: viewModel.snapshot.cards,
                  card: card,
                ),
              ),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Adicionar compra'),
            ),
            if (invoice.items.isNotEmpty) ...[
              const SizedBox(height: 12),
              _Footer(invoice: invoice),
            ],
          ],
        ),
      ),
    );
  }
}

class _ItemLine extends StatelessWidget {
  const _ItemLine({required this.item});

  final ExpenseOccurrence item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: () => ExpenseLedgerSheet.show(context, occurrence: item),
      leading: Icon(
        item.isPaid
            ? Icons.check_circle
            : item.isPartlyPaid
            ? Icons.incomplete_circle
            : Icons.circle_outlined,
        color: item.isPaid
            ? theme.colorScheme.primary
            : theme.colorScheme.onSurfaceVariant,
      ),
      title: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        item.installmentLabel != null
            ? 'Parcela ${item.installmentLabel}'
            : item.expense.type.label,
      ),
      trailing: Text(
        formatMoney(item.amount),
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.invoice});

  final CardInvoice invoice;

  @override
  Widget build(BuildContext context) {
    final viewModel = context.read<ExpensesViewModel>();
    final theme = Theme.of(context);

    if (invoice.isPaid) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Paga · ${formatMoney(invoice.paidAmount)}',
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => viewModel.clearInvoicePayments(invoice),
            icon: const Icon(Icons.undo, size: 18),
            label: const Text('Desfazer pagamento'),
          ),
        ],
      );
    }

    final walletId = viewModel.defaultWalletIdForInvoice(invoice);
    final wallet = viewModel.snapshot.walletById(walletId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Falta ${formatMoney(invoice.remaining)}',
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.error,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: () => viewModel.payInvoice(invoice, walletId: walletId),
          child: Text(
            wallet == null ? 'Pagar fatura' : 'Pagar fatura com ${wallet.name}',
          ),
        ),
      ],
    );
  }
}
