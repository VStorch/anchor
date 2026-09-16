import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/utils/money.dart';
import '../../../../core/utils/month.dart';
import '../../../budget/models/card_overview.dart';
import '../../../cards/models/card_invoice.dart';
import '../../../cards/models/credit_card.dart';
import '../../../cards/views/card_invoice_sheet.dart';
import '../../../expenses/views/expense_form_page.dart';
import '../../models/wallet.dart';

/// A card on the Carteiras tab: the invoice a purchase today goes to, the
/// older ones still unpaid, and the shortcut to add a purchase.
class CardOverviewTile extends StatelessWidget {
  const CardOverviewTile({
    super.key,
    required this.overview,
    required this.month,
    required this.wallets,
    required this.cards,
  });

  final CardOverview overview;
  final Month month;
  final List<Wallet> wallets;
  final List<CreditCard> cards;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final card = overview.card;
    final older = overview.pending.length - 1;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Icon(
                    CreditCard.icon,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    card.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            if (overview.pending.isNotEmpty)
              _InvoiceLine(invoice: overview.pending.first, label: null),
            if (older > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  older == 1
                      ? '+1 fatura anterior em aberto'
                      : '+$older faturas anteriores em aberto',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            _InvoiceLine(invoice: overview.shown, label: _shownLabel),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  ExpenseFormPage.route(
                    referenceMonth: month,
                    wallets: wallets,
                    cards: cards,
                    card: card,
                  ),
                ),
                style: const ButtonStyle(
                  minimumSize: WidgetStatePropertyAll<Size>(Size(0, 48)),
                ),
                icon: const Icon(Icons.add, size: 18),
                label: Text(
                  'Compra',
                  semanticsLabel: 'Adicionar compra no ${card.name}',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Outside the current month the line says which invoice it is showing.
  String? get _shownLabel => overview.isOpenInvoice
      ? null
      : 'Fatura de '
            '${DateFormat.MMMM('pt_BR').format(overview.shown.month.firstDay)}';
}

class _InvoiceLine extends StatelessWidget {
  const _InvoiceLine({required this.invoice, required this.label});

  final CardInvoice invoice;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = label == null
        ? invoice.statusLabel
        : '$label · ${invoice.statusLabel}';

    return MergeSemantics(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => CardInvoiceSheet.show(
          context,
          cardId: invoice.card.id!,
          month: invoice.month,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  status,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: invoice.isOverdue
                        ? theme.colorScheme.error
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (invoice.items.isNotEmpty)
                Text(
                  formatMoney(invoice.amount),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
