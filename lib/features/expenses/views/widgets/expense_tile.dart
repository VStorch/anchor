import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/utils/money.dart';
import '../../../wallets/models/wallet.dart';
import '../../models/expense_occurrence.dart';

class ExpenseTile extends StatelessWidget {
  const ExpenseTile({
    super.key,
    required this.occurrence,
    required this.wallet,
    required this.onTap,
    required this.onTogglePaid,
  });

  final ExpenseOccurrence occurrence;
  final Wallet? wallet;
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
          child: Row(
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
                          Text(
                            'Atrasada',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.error,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatMoney(occurrence.amount),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  _PaidToggle(
                    isPaid: occurrence.isPaid,
                    onPressed: onTogglePaid,
                  ),
                ],
              ),
            ],
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
    ];
    if (wallet != null) parts.add(wallet!.name);
    return parts.join(' · ');
  }
}

class _DueBadge extends StatelessWidget {
  const _DueBadge({required this.occurrence, required this.accent});

  final ExpenseOccurrence occurrence;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: 48,
      height: 48,
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
  const _PaidToggle({required this.isPaid, required this.onPressed});

  final bool isPaid;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return TextButton.icon(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        foregroundColor: isPaid
            ? theme.colorScheme.primary
            : theme.colorScheme.onSurfaceVariant,
      ),
      icon: Icon(isPaid ? Icons.check_circle : Icons.circle_outlined, size: 16),
      label: Text(isPaid ? 'Paga' : 'Pagar'),
    );
  }
}
