import 'package:flutter/material.dart';

import '../../../../core/utils/money.dart';
import '../../../budget/models/month_summary.dart';

class BalanceCard extends StatelessWidget {
  const BalanceCard({super.key, required this.summary});

  final MonthSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isNegative = summary.balance < 0;

    return Card(
      color: theme.colorScheme.primary,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Saldo de ${summary.month.label}',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onPrimary.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              formatMoney(summary.balance),
              style: theme.textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: isNegative
                    ? theme.colorScheme.errorContainer
                    : theme.colorScheme.onPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Recebido menos o que já foi pago',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onPrimary.withValues(alpha: 0.75),
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
                  ? '${formatMoney(summary.totalPending)} ainda a pagar'
                  : 'Todas as despesas do mês estão pagas',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              summary.projectedBalance >= 0
                  ? 'Pagando tudo, sobram ${formatMoney(summary.projectedBalance)} no mês'
                  : 'As despesas passam a renda do mês em '
                        '${formatMoney(summary.projectedBalance.abs())}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onPrimary.withValues(alpha: 0.75),
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
                    label: 'Despesas',
                    value: formatMoney(summary.totalExpenses),
                  ),
                ),
                Expanded(
                  child: _Figure(
                    label: 'Já paguei',
                    value: formatMoney(summary.totalPaid),
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
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onPrimary.withValues(alpha: 0.75),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onPrimary,
          ),
        ),
      ],
    );
  }
}
