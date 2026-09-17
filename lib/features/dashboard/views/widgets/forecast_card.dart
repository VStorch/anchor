import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/money_colors.dart';
import '../../../../core/utils/money.dart';
import '../../../budget/models/month_forecast.dart';

/// A forecast, drawn apart from the real figures and holding none of them.
/// Free money and benefits are told apart and never added up.
class ForecastCard extends StatelessWidget {
  const ForecastCard({super.key, required this.forecast});

  final MonthForecast forecast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = MoneyColors.of(context);
    final monthName = DateFormat.MMMM('pt_BR').format(forecast.month.firstDay);
    final free = forecast.freeMoney;
    final benefits = forecast.benefits;
    final headlineGroup = free.isEmpty ? benefits : free;
    final headlineBalance = headlineGroup.endBalance;

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
              _headline(free.isEmpty, headlineBalance),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: headlineBalance < 0
                    ? theme.colorScheme.error
                    : colors.predicted,
              ),
            ),
          ),
          if (!free.isEmpty && !benefits.isEmpty)
            for (final line in _benefitLines())
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                child: Text(
                  line.text,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: line.short
                        ? theme.colorScheme.error
                        : colors.predicted,
                  ),
                ),
              ),
          Theme(
            data: theme.copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 20),
              childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              expandedCrossAxisAlignment: CrossAxisAlignment.start,
              iconColor: colors.predicted,
              collapsedIconColor: colors.predicted,
              title: Text(
                'Como chegamos nisso',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              children: [
                if (!free.isEmpty)
                  _GroupBlock(title: 'Dinheiro livre', group: free),
                if (!free.isEmpty && !benefits.isEmpty)
                  const SizedBox(height: 12),
                if (!benefits.isEmpty)
                  _GroupBlock(title: 'Benefícios', group: benefits),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _headline(bool onlyBenefits, double balance) {
    final subject = onlyBenefits ? 'Nos benefícios' : 'Dinheiro livre';
    return balance < 0
        ? '$subject vai faltar ${formatMoney(-balance)}'
        : '$subject vai sobrar ${formatMoney(balance)}';
  }

  List<({String text, bool short})> _benefitLines() {
    final short = forecast.shortBenefits;
    if (short.isEmpty) {
      return [
        (
          text:
              'Nos benefícios: ${formatMoney(forecast.benefits.endBalance)} '
              'para usar',
          short: false,
        ),
      ];
    }
    return [
      for (final wallet in short)
        (
          text:
              'No ${wallet.wallet.name} vai faltar '
              '${formatMoney(-wallet.endBalance)}',
          short: true,
        ),
    ];
  }
}

class _GroupBlock extends StatelessWidget {
  const _GroupBlock({required this.title, required this.group});

  final String title;
  final ForecastGroup group;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        _Line(label: 'A receber', value: '+ ${formatMoney(group.toReceive)}'),
        _Line(label: 'Contas a pagar', value: '− ${formatMoney(group.toPay)}'),
        if (group.unassignedToPay > 0)
          _Line(
            label: 'Contas sem carteira',
            value: '− ${formatMoney(group.unassignedToPay)}',
          ),
        for (final wallet in group.wallets)
          _Line(
            label: wallet.wallet.name,
            value: formatMoney(wallet.endBalance),
            emphasized: true,
            short: wallet.endBalance < 0,
          ),
      ],
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({
    required this.label,
    required this.value,
    this.emphasized = false,
    this.short = false,
  });

  final String label;
  final String value;
  final bool emphasized;
  final bool short;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = short
        ? theme.colorScheme.error
        : MoneyColors.of(context).predicted;

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
                fontWeight: emphasized ? FontWeight.w700 : FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
