import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/utils/money.dart';
import '../../../budget/models/budget_snapshot.dart';

class BalanceCard extends StatelessWidget {
  const BalanceCard({super.key, required this.snapshot});

  final BudgetSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final summary = snapshot.summary;
    final balance = snapshot.walletsBalance;
    final monthName = DateFormat.MMMM('pt_BR').format(summary.month.firstDay);

    return Card(
      color: theme.colorScheme.primary,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Saldo total',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onPrimary.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              formatMoney(balance),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: balance < 0
                    ? theme.colorScheme.errorContainer
                    : theme.colorScheme.onPrimary,
              ),
            ),
            const SizedBox(height: 20),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: summary.paidRatio,
                minHeight: 8,
                color: theme.colorScheme.onPrimary,
                backgroundColor: theme.colorScheme.onPrimary.withValues(
                  alpha: 0.25,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              summary.totalPending > 0
                  ? '${formatMoney(summary.totalPending)} a pagar em $monthName'
                  : 'Tudo pago em $monthName',
              maxLines: 2,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _Figure(
                    label: 'Entrou',
                    value: formatMoney(summary.totalReceived),
                  ),
                ),
                Expanded(
                  child: _Figure(
                    label: 'Saiu',
                    value: formatMoney(summary.totalSpent),
                  ),
                ),
                Expanded(
                  child: _Figure(
                    label: 'Sobrou',
                    value: formatMoney(summary.balance),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onPrimary.withValues(alpha: 0.75),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onPrimary,
          ),
        ),
      ],
    );
  }
}
