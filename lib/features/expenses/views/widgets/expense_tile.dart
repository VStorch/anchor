import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/utils/money.dart';
import '../../../wallets/models/wallet.dart';
import '../../../cards/models/card_invoice.dart';
import '../../../cards/models/invoice_status.dart';
import '../../models/expense_occurrence.dart';
import '../../models/payable.dart';

class ExpenseTile extends StatelessWidget {
  const ExpenseTile({
    super.key,
    required this.payable,
    required this.wallets,
    required this.onTap,
  });

  final Payable payable;
  final List<Wallet> wallets;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = payable.isPaid
        ? theme.colorScheme.primary
        : payable.isOverdue
        ? theme.colorScheme.error
        : theme.colorScheme.onSurfaceVariant;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 16, 12),
          child: LayoutBuilder(
            builder: (context, constraints) => Row(
              children: [
                _DueBadge(payable: payable, accent: accent),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        payable.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          decoration: payable.isPaid
                              ? TextDecoration.lineThrough
                              : null,
                          decorationColor: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              _subtitle(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          if (payable.isOverdue) ...[
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'Atrasada',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.error,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (payable.isPartlyPaid) ...[
                        const SizedBox(height: 8),
                        _PartialBar(payable: payable),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: constraints.maxWidth * 0.42,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        formatMoney(payable.amount),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      _PaidToggle(payable: payable, onPressed: onTap),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _subtitle() => switch (payable) {
    ExpenseOccurrence occurrence => [
      occurrence.offRule
          ? 'Fora da regra atual'
          : occurrence.installmentLabel != null
          ? 'Parcela ${occurrence.installmentLabel}'
          : occurrence.expense.type.label,
      ..._walletNames(
        occurrence.payments.isNotEmpty
            ? occurrence.paidWalletIds
            : [?occurrence.plannedWalletId],
      ),
      if (occurrence.hasOutsidePayments) 'Outro dinheiro',
    ].join(' · '),
    CardInvoice invoice => [
      if (invoice.status case InvoiceStatus.open || InvoiceStatus.closed)
        invoice.status.label,
      invoice.items.length == 1
          ? '1 compra'
          : '${invoice.items.length} compras',
      ..._walletNames([?invoice.card.walletId]),
    ].join(' · '),
    _ => '',
  };

  List<String> _walletNames(List<int> ids) => ids
      .map((id) => wallets.where((wallet) => wallet.id == id).firstOrNull?.name)
      .whereType<String>()
      .toList();
}

class _PartialBar extends StatelessWidget {
  const _PartialBar({required this.payable});

  final Payable payable;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: payable.paidRatio,
            minHeight: 4,
            color: theme.colorScheme.primary,
            backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.15),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${formatMoney(payable.paidAmount)} pagos · faltam ${formatMoney(payable.remaining)}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _DueBadge extends StatelessWidget {
  const _DueBadge({required this.payable, required this.accent});

  final Payable payable;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final side = MediaQuery.textScalerOf(context).scale(48).clamp(48.0, 62.0);

    return Container(
      width: side,
      height: side,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${payable.dueDate.day}',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: accent,
              height: 1,
            ),
          ),
          Text(
            DateFormat.MMM('pt_BR').format(payable.dueDate).replaceAll('.', ''),
            style: theme.textTheme.labelSmall?.copyWith(color: accent),
          ),
        ],
      ),
    );
  }
}

class _PaidToggle extends StatelessWidget {
  const _PaidToggle({required this.payable, required this.onPressed});

  final Payable payable;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = payable.isPaid
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant;

    return LayoutBuilder(
      builder: (context, constraints) {
        final fitsLabel =
            constraints.maxWidth >= MediaQuery.textScalerOf(context).scale(96);

        if (!fitsLabel) {
          return IconButton(
            onPressed: onPressed,
            visualDensity: VisualDensity.compact,
            color: color,
            tooltip: _label,
            icon: Icon(_icon, size: 20),
          );
        }

        return TextButton.icon(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            foregroundColor: color,
          ),
          icon: Icon(_icon, size: 16),
          label: Text(_label),
        );
      },
    );
  }

  IconData get _icon => payable.isPaid
      ? Icons.check_circle
      : payable.isPartlyPaid
      ? Icons.incomplete_circle
      : Icons.circle_outlined;

  String get _label => payable.isPaid
      ? 'Paga'
      : payable.isPartlyPaid
      ? 'Parcial'
      : 'Pagar';
}
