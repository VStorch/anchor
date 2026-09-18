import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/money_colors.dart';
import '../../../../core/utils/money.dart';
import '../../../budget/models/month_forecast.dart';
import '../../../wallets/models/wallet.dart';

/// A forecast, drawn apart from the real figures and holding none of them.
/// Free money and benefits are told apart and never added up.
class ForecastCard extends StatelessWidget {
  const ForecastCard({super.key, required this.forecast, this.onEditReserve});

  final MonthForecast forecast;

  /// Opens the everyday-spending reserve, on the salary given when there is
  /// one to edit.
  final ValueChanged<Wallet?>? onEditReserve;

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
          if (_dailyLine() case final daily?)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Text(
                daily,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colors.predicted,
                ),
              ),
            ),
          if (free.hasReserve && onEditReserve != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 20, 0),
              child: TextButton.icon(
                onPressed: () => onEditReserve!(_reservedWallet(free)),
                style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: Text(
                  'Reserva: ${formatMoney(_monthlyReserve(free))}/mês',
                ),
              ),
            ),
          if (free.lacksReserve && onEditReserve != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextButton.icon(
                    onPressed: () => onEditReserve!(null),
                    style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
                    icon: const Icon(Icons.add),
                    label: const Text('Reservar gasto do dia a dia'),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: Text(
                      'A previsão ainda não conta mercado, transporte e '
                      'lanches.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
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

  /// " (hoje já saiu R$ 25,00)", so a spending launched today is seen
  /// inside the day's figure rather than on top of it.
  static String _spentTodayNote(ForecastGroup group) => group.spentToday > 0
      ? ' (hoje já saiu ${formatMoney(group.spentToday)})'
      : '';

  /// "Por dia até 30/09: R$ 20,00 do salário · R$ 7,35 no VR"; only for
  /// the current month, where "today" means something.
  String? _dailyLine() {
    final parts = [
      if (forecast.freeMoney.dailyAllowance case final free?)
        '${forecast.freeMoney.reserveUsedUp ? 'Reserva de '
                      '${DateFormat.MMMM('pt_BR').format(forecast.month.firstDay)} '
                      'já usada' : '${formatMoney(free)} do salário'}'
            '${_spentTodayNote(forecast.freeMoney)}',
      if (forecast.benefits.dailyAllowance case final benefit?)
        '${formatMoney(benefit)} ${_benefitPlace()}',
    ];
    if (parts.isEmpty) return null;
    final lastDay = forecast.month.dayOf(forecast.month.lengthInDays);
    return 'Por dia até ${DateFormat('dd/MM').format(lastDay)}: '
        '${parts.join(' · ')}';
  }

  String _benefitPlace() {
    final wallets = forecast.benefits.wallets;
    return wallets.length == 1
        ? 'no ${wallets.single.wallet.name}'
        : 'nos benefícios';
  }

  static Wallet? _reservedWallet(ForecastGroup group) => group.wallets
      .map((forecast) => forecast.wallet)
      .where((wallet) => wallet.monthlyReserve != null)
      .firstOrNull;

  static double _monthlyReserve(ForecastGroup group) => group.wallets.fold(
    0,
    (total, forecast) => total + (forecast.wallet.monthlyReserve ?? 0),
  );

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
    final shares = group.reserveShares;

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
        if (group.wallets.isNotEmpty) ...[
          _Line(label: 'Você tem hoje', value: formatMoney(group.startBalance)),
          _Line(label: 'A receber', value: '+ ${formatMoney(group.toReceive)}'),
          _Line(
            label: 'Contas a pagar',
            value: '− ${formatMoney(group.toPay)}',
          ),
        ],
        if (group.hasReserve)
          _Line(
            label: shares.length > 1
                ? 'Reserva do dia a dia · ${_sharesLabel(group, shares)}'
                : 'Reserva do dia a dia · ${_daysLabel(group)}',
            value: '− ${formatMoney(group.reserve)}',
          ),
        if (group.unassignedToPay > 0)
          _Line(
            label: 'Contas sem carteira',
            value: '− ${formatMoney(group.unassignedToPay)}',
          ),
        if (group.wallets.length > 1)
          for (final wallet in group.wallets)
            _Line(
              label: wallet.wallet.name,
              value: formatMoney(wallet.endBalance),
              short: wallet.endBalance < 0,
            ),
        const Divider(height: 12),
        _Line(
          label: group.endBalance < 0 ? 'Vai faltar' : 'Vai sobrar',
          value: formatMoney(group.endBalance.abs()),
          emphasized: true,
          short: group.endBalance < 0,
        ),
      ],
    );
  }

  /// "13 dias de 30": where this month's share of the reserve comes from.
  static String _daysLabel(ForecastGroup group) =>
      '${group.daysLeftInCurrentMonth} dias de ${group.daysInCurrentMonth}';

  /// "R$ 235,00 em setembro (13 dias de 30) + R$ 600,00 em outubro".
  static String _sharesLabel(ForecastGroup group, List<ReserveShare> shares) =>
      [
        for (final (index, share) in shares.indexed)
          '${formatMoney(share.amount)} em '
              '${DateFormat.MMMM('pt_BR').format(share.month.firstDay)}'
              '${index == 0 ? ' (${_daysLabel(group)})' : ''}',
      ].join(' + ');
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
