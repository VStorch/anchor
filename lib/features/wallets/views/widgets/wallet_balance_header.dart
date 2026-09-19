import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/utils/moment.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/utils/month.dart';
import '../../../budget/models/wallet_summary.dart';

/// The wallet balance and the lines that explain it: what was informed and
/// what moved after it (on the wallet's own page), then what the month on
/// screen did.
class WalletBalanceHeader extends StatelessWidget {
  const WalletBalanceHeader({
    super.key,
    required this.summary,
    required this.month,
    this.showBalanceLine = true,
  });

  final WalletSummary summary;
  final Month month;

  /// Off on the Carteiras tab, where the Resumo already explains the
  /// balance; TalkBack still reads it with the figure.
  final bool showBalanceLine;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondary = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            formatMoney(summary.balance),
            semanticsLabel: showBalanceLine
                ? null
                : '${formatMoney(summary.balance)}. $balanceLine',
            maxLines: 1,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: summary.balance < 0
                  ? theme.colorScheme.error
                  : theme.colorScheme.onSurface,
            ),
          ),
        ),
        if (showBalanceLine) ...[
          const SizedBox(height: 4),
          Text(balanceLine, style: secondary),
        ],
        const SizedBox(height: 2),
        Text(monthLine, style: secondary),
      ],
    );
  }

  /// "Saldo de 15/09, 9h04: R$ 850,00 · −R$ 99,90 depois", or what stands
  /// in for it when there is no check or nothing moved after it.
  String get balanceLine {
    final check = summary.latestCheck;
    final moved = _movedLabels;

    if (check == null) {
      if (moved.isEmpty) return 'Nada lançado ainda';
      return 'Desde o cadastro: ${moved.join(' ')}';
    }
    final informed = 'Saldo de ${_momentLabel(check.checkedAt)}';
    if (moved.isEmpty) return informed;
    return '$informed: ${formatMoney(check.amount)} · '
        '${moved.join(' ')} depois';
  }

  String get monthLine {
    final name = _monthName;
    if (summary.receivedInMonth == 0 && summary.spentInMonth == 0) {
      return '$name: nada lançado';
    }
    return '$name: entrou ${formatMoney(summary.receivedInMonth)}'
        ' · saiu ${formatMoney(summary.spentInMonth)}';
  }

  List<String> get _movedLabels => <String>[
    if (summary.receivedSinceCheck > 0)
      '+${formatMoney(summary.receivedSinceCheck)}',
    if (summary.spentSinceCheck > 0) '−${formatMoney(summary.spentSinceCheck)}',
  ];

  String get _monthName => toBeginningOfSentenceCase(
    DateFormat.MMMM('pt_BR').format(month.firstDay),
  )!;

  static String _momentLabel(DateTime at) {
    final day = DateFormat('dd/MM').format(at);
    if (closesDay(at)) return day;
    return '$day, ${DateFormat("H'h'mm").format(at)}';
  }
}
