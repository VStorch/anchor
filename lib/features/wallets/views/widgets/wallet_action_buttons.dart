import 'package:flutter/material.dart';

import '../../../../app/theme/money_icons.dart';
import '../../../budget/models/wallet_summary.dart';

/// Gasto, Entrada and Informar saldo, in the same order on every wallet. A
/// Wrap, because three buttons never fit a row at 320dp.
class WalletActionButtons extends StatelessWidget {
  const WalletActionButtons({
    super.key,
    required this.summary,
    required this.onOutflow,
    required this.onReceipt,
    required this.onCheck,
  });

  final WalletSummary summary;
  final VoidCallback onOutflow;
  final VoidCallback onReceipt;
  final VoidCallback onCheck;

  static const ButtonStyle _style = ButtonStyle(
    minimumSize: WidgetStatePropertyAll<Size>(Size(0, 48)),
  );

  @override
  Widget build(BuildContext context) {
    final name = summary.wallet.name;
    final spending = FilledButton.tonalIcon(
      onPressed: onOutflow,
      style: _style,
      icon: const Icon(Icons.add, size: 18),
      label: Text('Gasto', semanticsLabel: 'Registrar gasto no $name'),
    );
    final income = OutlinedButton.icon(
      onPressed: onReceipt,
      style: _style,
      icon: const Icon(Icons.add, size: 18),
      label: Text('Entrada', semanticsLabel: 'Registrar entrada no $name'),
    );
    final check = OutlinedButton.icon(
      onPressed: onCheck,
      style: _style,
      icon: const Icon(MoneyIcons.check, size: 18),
      label: Text('Informar saldo', semanticsLabel: 'Informar saldo do $name'),
    );

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[spending, income, check],
    );
  }
}
