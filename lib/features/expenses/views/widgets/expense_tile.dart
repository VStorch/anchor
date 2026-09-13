import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/utils/money.dart';
import '../../../wallets/models/wallet.dart';
import '../../models/expense_occurrence.dart';

class ExpenseTile extends StatelessWidget {
  const ExpenseTile({
    super.key,
    required this.occurrence,
    required this.wallets,
    required this.onTap,
    required this.onTogglePaid,
  });

  final ExpenseOccurrence occurrence;
  final List<Wallet> wallets;
  final VoidCallback onTap;
  final VoidCallback onTogglePaid;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final expense = occurrence.expense;
    final accent = occurrence.isPaid
        ? theme.colorScheme.primary
        : occurrence.isOverdue
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
                _DueBadge(occurrence: occurrence, accent: accent),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        expense.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          decoration: occurrence.isPaid
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
                          if (occurrence.isOverdue) ...[
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
                      if (occurrence.isPartlyPaid) ...[
                        const SizedBox(height: 8),
                        _PartialBar(occurrence: occurrence),
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
                        formatMoney(occurrence.amount),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      _PaidToggle(
                        occurrence: occurrence,
                        onPressed: onTogglePaid,
                      ),
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

  String _subtitle() {
    final installment = occurrence.installmentLabel;
    final parts = <String>[
      installment != null
          ? 'Parcela $installment'
          : occurrence.expense.type.label,
      ..._walletNames(),
    ];
    return parts.join(' · ');
  }

  List<String> _walletNames() {
    final ids = occurrence.paidWalletIds.isNotEmpty
        ? occurrence.paidWalletIds
        : <int>[
            if (occurrence.plannedWalletId != null) occurrence.plannedWalletId!,
          ];

    return ids
        .map(
          (id) => wallets.where((wallet) => wallet.id == id).firstOrNull?.name,
        )
        .whereType<String>()
        .toList();
  }
}

class _PartialBar extends StatelessWidget {
  const _PartialBar({required this.occurrence});

  final ExpenseOccurrence occurrence;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: occurrence.paidRatio,
            minHeight: 4,
            color: theme.colorScheme.primary,
            backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.15),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${formatMoney(occurrence.paidAmount)} pagos · faltam ${formatMoney(occurrence.remaining)}',
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
  const _DueBadge({required this.occurrence, required this.accent});

  final ExpenseOccurrence occurrence;
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
            '${occurrence.dueDate.day}',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: accent,
              height: 1,
            ),
          ),
          Text(
            DateFormat.MMM(
              'pt_BR',
            ).format(occurrence.dueDate).replaceAll('.', ''),
            style: theme.textTheme.labelSmall?.copyWith(color: accent),
          ),
        ],
      ),
    );
  }
}

class _PaidToggle extends StatelessWidget {
  const _PaidToggle({required this.occurrence, required this.onPressed});

  final ExpenseOccurrence occurrence;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = occurrence.isPaid
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

  IconData get _icon => occurrence.isPaid
      ? Icons.check_circle
      : occurrence.isPartlyPaid
      ? Icons.incomplete_circle
      : Icons.circle_outlined;

  String get _label => occurrence.isPaid
      ? 'Paga'
      : occurrence.isPartlyPaid
      ? 'Parcial'
      : 'Pagar';
}
