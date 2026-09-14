import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/money_colors.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/utils/month.dart';
import '../../../budget/models/month_summary.dart';

/// What already happened in the month on screen: confirmed money only.
class MonthSoFarCard extends StatelessWidget {
  const MonthSoFarCard({super.key, required this.summary});

  final MonthSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = MoneyColors.of(context);
    final isCurrent = summary.month == Month.fromDate(summary.today);
    final monthName = toBeginningOfSentenceCase(
      DateFormat.MMMM('pt_BR').format(summary.month.firstDay),
    );
    final difference = summary.difference;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isCurrent ? '$monthName até agora' : summary.month.label,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _Figure(
                    label: 'Entrou',
                    value: formatMoney(summary.totalReceived),
                    color: colors.income,
                  ),
                ),
                Expanded(
                  child: _Figure(
                    label: 'Saiu',
                    value: formatMoney(summary.totalSpent),
                    color: colors.spending,
                  ),
                ),
                Expanded(
                  child: _Figure(
                    label: 'Diferença',
                    value: formatMoney(difference),
                    color: difference < 0
                        ? theme.colorScheme.error
                        : colors.neutral,
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
  const _Figure({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

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
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            maxLines: 1,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}
