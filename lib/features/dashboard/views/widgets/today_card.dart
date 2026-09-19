import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/utils/moment.dart';
import '../../../../core/utils/money.dart';
import '../../../budget/models/wallet_summary.dart';

/// The money that exists right now, whatever month is on screen, and where
/// each wallet's part of it comes from.
class TodayCard extends StatelessWidget {
  const TodayCard({
    super.key,
    required this.balance,
    required this.wallets,
    required this.awaitingConfirmation,
    required this.onConfirm,
  });

  final double balance;
  final List<WalletSummary> wallets;
  final double awaitingConfirmation;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onPrimary = theme.colorScheme.onPrimary;

    return Card(
      color: theme.colorScheme.primary,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Você tem hoje',
              style: theme.textTheme.labelMedium?.copyWith(
                color: onPrimary.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                formatMoney(balance),
                maxLines: 1,
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: balance < 0
                      ? theme.colorScheme.errorContainer
                      : onPrimary,
                ),
              ),
            ),
            if (wallets.isNotEmpty) _breakdown(context, onPrimary),
            if (awaitingConfirmation > 0) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onConfirm,
                style: FilledButton.styleFrom(
                  backgroundColor: onPrimary,
                  foregroundColor: theme.colorScheme.primary,
                ),
                icon: const Icon(Icons.task_alt),
                label: Text(
                  'Confirmar ${formatMoney(awaitingConfirmation)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _breakdown(BuildContext context, Color onPrimary) {
    final theme = Theme.of(context);

    return Theme(
      data: theme.copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        title: Text(
          'De onde vem esse valor',
          style: theme.textTheme.labelLarge?.copyWith(color: onPrimary),
        ),
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
        iconColor: onPrimary,
        collapsedIconColor: onPrimary,
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final summary in wallets)
            _WalletBreakdown(
              summary: summary,
              showsName: wallets.length > 1,
              onPrimary: onPrimary,
            ),
        ],
      ),
    );
  }
}

class _WalletBreakdown extends StatelessWidget {
  const _WalletBreakdown({
    required this.summary,
    required this.showsName,
    required this.onPrimary,
  });

  final WalletSummary summary;
  final bool showsName;
  final Color onPrimary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lines = _lines();

    return Semantics(
      label: [
        if (showsName)
          '${summary.wallet.name}, ${formatMoney(summary.balance)}',
        for (final line in lines)
          line.value == null
              ? line.label
              : '${line.label}: ${formatMoney(line.value!)}',
      ].join('. '),
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showsName)
                _Line(
                  label: summary.wallet.name,
                  value: formatMoney(summary.balance),
                  onPrimary: onPrimary,
                  style: theme.textTheme.labelLarge,
                ),
              for (final line in lines)
                Padding(
                  padding: EdgeInsets.only(left: showsName ? 12 : 0, top: 4),
                  child: _Line(
                    label: line.label,
                    value: line.value == null
                        ? null
                        : '${line.sign}${formatMoney(line.value!)}',
                    onPrimary: onPrimary.withValues(alpha: 0.85),
                    style: theme.textTheme.bodySmall,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  List<_BreakdownLine> _lines() {
    final check = summary.latestCheck;
    final since = check != null ? ' depois' : '';
    final moved = summary.receivedSinceCheck > 0 || summary.spentSinceCheck > 0;

    return <_BreakdownLine>[
      if (check != null)
        _BreakdownLine(label: _checkLabel(check.checkedAt), value: check.amount)
      else
        _BreakdownLine(label: _sinceCreationLabel()),
      if (summary.receivedSinceCheck > 0)
        _BreakdownLine(
          label: 'Entrou$since',
          value: summary.receivedSinceCheck,
          sign: '+ ',
        ),
      if (summary.spentSinceCheck > 0)
        _BreakdownLine(
          label: 'Saiu$since',
          value: summary.spentSinceCheck,
          sign: '− ',
        ),
      if (!moved)
        _BreakdownLine(
          label: check != null ? 'Nada lançado depois' : 'Nada lançado ainda',
        ),
    ];
  }

  String _checkLabel(DateTime at) {
    final day = DateFormat('dd/MM').format(at);
    if (closesDay(at)) return 'Saldo de $day';
    return 'Saldo de $day, ${DateFormat("H'h'mm").format(at)}';
  }

  String _sinceCreationLabel() =>
      'Cadastro em '
      '${DateFormat('dd/MM').format(summary.wallet.createdAt)}';
}

class _BreakdownLine {
  const _BreakdownLine({required this.label, this.value, this.sign = ''});

  final String label;
  final double? value;
  final String sign;
}

class _Line extends StatelessWidget {
  const _Line({
    required this.label,
    required this.value,
    required this.onPrimary,
    this.style,
  });

  final String label;
  final String? value;
  final Color onPrimary;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final text = style?.copyWith(color: onPrimary);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Text(label, maxLines: 2, style: text)),
        if (value != null) ...[
          const SizedBox(width: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value!, maxLines: 1, style: text),
          ),
        ],
      ],
    );
  }
}
