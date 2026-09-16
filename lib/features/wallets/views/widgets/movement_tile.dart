import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/money_colors.dart';
import '../../../../app/theme/money_icons.dart';
import '../../../../core/utils/money.dart';
import '../../models/wallet.dart';
import '../../models/wallet_movement.dart';

/// One line of a wallet statement: a receipt, an outflow, a bill paid from
/// the wallet or a balance check.
class MovementTile extends StatelessWidget {
  const MovementTile({
    super.key,
    required this.movement,
    required this.wallet,
    required this.onTap,
    this.showsWallet = true,
  });

  final WalletMovement movement;
  final Wallet? wallet;
  final VoidCallback onTap;

  /// A statement of a single wallet never repeats its name.
  final bool showsWallet;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = MoneyColors.of(context);
    final color = movement.isCheck
        ? colors.neutral
        : movement.isPredicted
        ? colors.predicted
        : movement.isIncome
        ? colors.income
        : colors.spending;
    final notes = [
      if (movement.isPredicted) 'a confirmar',
      if (!movement.countsInBalance) 'antes do saldo informado',
    ];

    return Opacity(
      opacity: movement.countsInBalance ? 1 : 0.6,
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        onTap: movement.isEditable ? onTap : null,
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.14),
          child: Icon(_icon, size: 18, color: color),
        ),
        title: Text(
          movement.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          [
            DateFormat.MMMd('pt_BR').format(movement.date),
            if (showsWallet && !movement.titleIsWalletName)
              wallet?.name ?? 'Carteira removida',
            ...notes,
          ].join(' · '),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Text(
          movement.isCheck ? formatMoney(movement.amount) : _signedAmount,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ),
    );
  }

  String get _signedAmount {
    final sign = movement.amount > 0
        ? '+'
        : movement.amount < 0
        ? '−'
        : '';
    return '$sign${formatMoney(movement.amount.abs())}';
  }

  IconData get _icon {
    if (movement.isCheck) return MoneyIcons.check;
    return movement.isIncome ? MoneyIcons.income : MoneyIcons.spending;
  }
}
