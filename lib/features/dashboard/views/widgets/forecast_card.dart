import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/money_colors.dart';
import '../../../../core/utils/money.dart';
import '../../../budget/models/month_forecast.dart';

/// A forecast, drawn apart from the real figures and holding none of them.
class ForecastCard extends StatelessWidget {
  const ForecastCard({super.key, required this.forecast});

  final MonthForecast forecast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = MoneyColors.of(context);
    final monthName = DateFormat.MMMM('pt_BR').format(forecast.month.firstDay);
    final endBalance = forecast.endBalance;
    final falls = endBalance < 0;

    return Card(
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: colors.predicted.withValues(alpha: 0.6)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
            child: Row(
              children: [
                Icon(
                  Icons.insights_outlined,
                  size: 18,
                  color: colors.predicted,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Previsão até o fim de $monthName',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: colors.predicted,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
            child: Text(
              falls
                  ? 'Vai faltar ${formatMoney(-endBalance)}'
                  : 'Vai sobrar ${formatMoney(endBalance)}',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: falls ? theme.colorScheme.error : colors.predicted,
              ),
            ),
          ),
          Theme(
            data: theme.copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 20),
              childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              iconColor: colors.predicted,
              collapsedIconColor: colors.predicted,
              title: Text(
                'Como chegamos nisso',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              children: [
                _Line(
                  label: 'A receber',
                  value: '+ ${formatMoney(forecast.toReceive)}',
                ),
                _Line(
                  label: 'A pagar',
                  value: '− ${formatMoney(forecast.toPay)}',
                ),
                const Divider(height: 20),
                for (final wallet in forecast.wallets)
                  _Line(
                    label: wallet.wallet.name,
                    value: formatMoney(wallet.endBalance),
                  ),
                if (forecast.unassignedToPay > 0)
                  _Line(
                    label: 'Sem carteira definida',
                    value: '− ${formatMoney(forecast.unassignedToPay)}',
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: MoneyColors.of(context).predicted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
