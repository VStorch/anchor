import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/utils/money.dart';
import '../../../../core/utils/month.dart';
import '../../../budget/models/wallet_summary.dart';
import '../../../cards/models/credit_card.dart';
import '../../models/spending_source.dart';

/// "Novo gasto": which wallet the money left, which card it was bought on,
/// or that it is a bill with a due day.
class SpendingSourceSheet extends StatelessWidget {
  const SpendingSourceSheet({
    super.key,
    required this.wallets,
    required this.cards,
    required this.invoiceMonthOf,
  });

  static Future<SpendingSource?> show(
    BuildContext context, {
    required List<WalletSummary> wallets,
    required List<CreditCard> cards,
    required Month Function(CreditCard) invoiceMonthOf,
  }) {
    return showModalBottomSheet<SpendingSource>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => SpendingSourceSheet(
        wallets: wallets,
        cards: cards,
        invoiceMonthOf: invoiceMonthOf,
      ),
    );
  }

  final List<WalletSummary> wallets;
  final List<CreditCard> cards;
  final Month Function(CreditCard) invoiceMonthOf;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'De onde saiu o dinheiro?',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            for (final summary in wallets)
              ListTile(
                contentPadding: EdgeInsets.zero,
                onTap: () =>
                    Navigator.pop(context, WalletSource(summary.wallet)),
                leading: CircleAvatar(
                  backgroundColor: summary.wallet.color.withValues(alpha: 0.16),
                  child: Icon(summary.wallet.icon, color: summary.wallet.color),
                ),
                title: Text(summary.wallet.name),
                subtitle: Text('Saldo ${formatMoney(summary.balance)}'),
              ),
            if (cards.isNotEmpty) ...[
              const Divider(),
              for (final card in cards)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  onTap: () => Navigator.pop(context, CardSource(card)),
                  leading: CircleAvatar(
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Icon(
                      CreditCard.icon,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                  title: Text(card.name),
                  subtitle: Text(
                    'Entra na fatura de '
                    '${DateFormat.MMMM('pt_BR').format(invoiceMonthOf(card).firstDay)}',
                  ),
                ),
            ],
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => Navigator.pop(context, const BillSource()),
              style: TextButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                alignment: Alignment.centerLeft,
              ),
              icon: const Icon(Icons.receipt_long_outlined),
              label: const Text('É uma conta com vencimento'),
            ),
          ],
        ),
      ),
    );
  }
}
