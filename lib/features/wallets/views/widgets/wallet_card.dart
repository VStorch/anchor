import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/utils/money.dart';
import '../../../../core/utils/month.dart';
import '../../../budget/models/wallet_summary.dart';
import '../../models/wallet_kind.dart';
import 'wallet_action_buttons.dart';
import 'wallet_balance_header.dart';

class WalletCard extends StatelessWidget {
  const WalletCard({
    super.key,
    required this.summary,
    required this.month,
    required this.onTap,
    required this.onRegisterReceipt,
    required this.onRegisterOutflow,
    required this.onCheckBalance,
    this.onConfirm,
  });

  final WalletSummary summary;
  final Month month;
  final VoidCallback onTap;
  final VoidCallback onRegisterReceipt;
  final VoidCallback onRegisterOutflow;
  final VoidCallback onCheckBalance;
  final VoidCallback? onConfirm;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final wallet = summary.wallet;

    return Card(
      child: Semantics(
        button: true,
        hint: 'Abrir extrato',
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: wallet.color.withValues(alpha: 0.16),
                      child: Icon(wallet.icon, color: wallet.color),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        wallet.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                WalletBalanceHeader(summary: summary, month: month),
                if (onConfirm != null && summary.unconfirmedInMonth > 0) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.tonalIcon(
                          onPressed: onConfirm,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                          ),
                          icon: const Icon(Icons.task_alt, size: 18),
                          label: Text(
                            summary.unconfirmedInMonth == 1
                                ? 'Confirmar ${formatMoney(summary.pendingConfirmationInMonth)}'
                                : 'Confirmar (${summary.unconfirmedInMonth})',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                if (wallet.kind == WalletKind.benefit) ...[
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: summary.leftRatio,
                      minHeight: 6,
                      semanticsLabel: 'Parte do saldo que ainda resta',
                      semanticsValue: '${(summary.leftRatio * 100).round()}%',
                      color: wallet.color,
                      backgroundColor: wallet.color.withValues(alpha: 0.15),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Saiu ${formatMoney(summary.spentInCurrentMonth)} em '
                    '${DateFormat.MMMM('pt_BR').format((summary.currentMonth ?? month).firstDay)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                WalletActionButtons(
                  summary: summary,
                  onOutflow: onRegisterOutflow,
                  onReceipt: onRegisterReceipt,
                  onCheck: onCheckBalance,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
