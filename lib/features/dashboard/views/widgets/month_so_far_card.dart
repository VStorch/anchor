import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/money_colors.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/utils/month.dart';
import '../../../budget/models/month_reconciliation.dart';
import '../../../budget/models/month_summary.dart';

/// What already happened in the month on screen: confirmed money only.
class MonthSoFarCard extends StatelessWidget {
  const MonthSoFarCard({
    super.key,
    required this.summary,
    required this.reconciliation,
  });

  final MonthSummary summary;
  final MonthReconciliation reconciliation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = MoneyColors.of(context);
    final isCurrent = summary.month == Month.fromDate(summary.today);
    final monthName = toBeginningOfSentenceCase(
      DateFormat.MMMM('pt_BR').format(summary.month.firstDay),
    );
    final change = reconciliation.balanceChange;
    final showsChange = change != null && !reconciliation.isEmpty;

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
                if (showsChange)
                  Expanded(
                    child: _Figure(
                      label: change < 0 ? 'Tirou do saldo' : 'Somou ao saldo',
                      value: formatMoney(change.abs()),
                      color: change < 0
                          ? theme.colorScheme.error
                          : colors.neutral,
                    ),
                  ),
              ],
            ),
            if (!showsChange) ...[
              const SizedBox(height: 12),
              _Note(
                text: reconciliation.isEmpty
                    ? 'Nada lançado em ${monthName.toLowerCase()}'
                          '${isCurrent ? ' ainda' : ''}.'
                    : _alreadyInBalance(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// What of the month is inside a balance the user informed, so the figures
  /// above never read as money that is still there.
  String _alreadyInBalance() {
    final received = reconciliation.receivedBeforeCheck;
    final spent = reconciliation.spentBeforeCheck;
    final parts = <String>[
      if (received > 0) '${formatMoney(received)} do que entrou',
      if (spent > 0) '${formatMoney(spent)} do que saiu',
    ];
    final verb = parts.length > 1 ? 'já estavam' : 'já estava';
    return '${parts.join(' e ')} $verb ${_checksLabel()}.';
  }

  String _checksLabel() {
    final checks = reconciliation.coveringChecks;
    final day = DateFormat('dd/MM');
    final days = checks.map((covering) => day.format(covering.check.checkedAt));
    if (days.toSet().length == 1) {
      return 'no saldo que você informou em ${days.first}';
    }
    final named = checks
        .map(
          (covering) =>
              '${covering.wallet.name} '
              '${day.format(covering.check.checkedAt)}',
        )
        .join(', ');
    return 'nos saldos que você informou ($named)';
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.info_outline,
          size: 16,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: style)),
      ],
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
          maxLines: 2,
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
