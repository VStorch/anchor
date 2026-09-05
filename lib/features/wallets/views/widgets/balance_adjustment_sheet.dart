import 'package:flutter/material.dart';

import '../../../../core/utils/money.dart';
import '../../../../core/widgets/money_field.dart';
import '../../models/wallet.dart';

class BalanceAdjustmentSheet extends StatefulWidget {
  const BalanceAdjustmentSheet({
    super.key,
    required this.wallet,
    required this.currentBalance,
  });

  static Future<double?> show(
    BuildContext context, {
    required Wallet wallet,
    required double currentBalance,
  }) {
    return showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => BalanceAdjustmentSheet(
        wallet: wallet,
        currentBalance: currentBalance,
      ),
    );
  }

  final Wallet wallet;
  final double currentBalance;

  @override
  State<BalanceAdjustmentSheet> createState() => _BalanceAdjustmentSheetState();
}

class _BalanceAdjustmentSheetState extends State<BalanceAdjustmentSheet> {
  late double _balance = widget.currentBalance;

  double get _difference => _balance - widget.currentBalance;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Saldo de ${widget.wallet.name}',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Informe quanto tem de verdade. A diferença entra como um '
              'ajuste, sem virar entrada do mês.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            MoneyField(
              initialValue: _balance,
              label: 'Saldo real',
              autofocus: true,
              onChanged: (value) => setState(() => _balance = value),
            ),
            const SizedBox(height: 16),
            _DifferenceLine(
              currentBalance: widget.currentBalance,
              difference: _difference,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _difference.abs() < 0.005
                  ? null
                  : () => Navigator.of(context).pop(_balance),
              child: const Text('Ajustar saldo'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DifferenceLine extends StatelessWidget {
  const _DifferenceLine({
    required this.currentBalance,
    required this.difference,
  });

  final double currentBalance;
  final double difference;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (difference.abs() < 0.005) {
      return Text(
        'O app já mostra ${formatMoney(currentBalance)}.',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }

    final isCredit = difference > 0;

    return Row(
      children: [
        Icon(
          isCredit ? Icons.arrow_upward : Icons.arrow_downward,
          size: 16,
          color: isCredit ? theme.colorScheme.primary : theme.colorScheme.error,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Ajuste de ${formatMoney(difference.abs())} '
            '${isCredit ? 'a mais' : 'a menos'} '
            'sobre ${formatMoney(currentBalance)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
