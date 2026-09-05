import 'package:flutter/material.dart';

import '../../../../core/utils/money.dart';
import '../../../budget/models/wallet_summary.dart';

class WalletCard extends StatelessWidget {
  const WalletCard({
    super.key,
    required this.summary,
    required this.onTap,
    required this.onRegisterReceipt,
    required this.onAdjustBalance,
  });

  final WalletSummary summary;
  final VoidCallback onTap;
  final VoidCallback onRegisterReceipt;
  final VoidCallback onAdjustBalance;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final wallet = summary.wallet;

    return Card(
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
                  if (summary.unconfirmedInMonth > 0)
                    Flexible(
                      child: Chip(
                        visualDensity: VisualDensity.compact,
                        backgroundColor: theme.colorScheme.tertiaryContainer,
                        side: BorderSide.none,
                        avatar: Icon(
                          Icons.schedule,
                          size: 14,
                          color: theme.colorScheme.onTertiaryContainer,
                        ),
                        label: Text(
                          '${summary.unconfirmedInMonth} a confirmar',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onTertiaryContainer,
                          ),
                        ),
                      ),
                    ),
                  IconButton(
                    onPressed: onRegisterReceipt,
                    icon: const Icon(Icons.add_card_outlined),
                    tooltip: 'Registrar entrada',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _Metric(
                      label: 'Saldo',
                      value: formatMoney(summary.balance),
                      color: summary.balance < 0
                          ? theme.colorScheme.error
                          : wallet.color,
                      onTap: onAdjustBalance,
                    ),
                  ),
                  Expanded(
                    child: _Metric(
                      label: 'Recebido',
                      value: formatMoney(summary.receivedInMonth),
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  Expanded(
                    child: _Metric(
                      label: 'Gasto',
                      value: formatMoney(summary.spentInMonth),
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              if (summary.receivedInMonth > 0) ...[
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: summary.usageRatio,
                    minHeight: 6,
                    color: wallet.color,
                    backgroundColor: wallet.color.withValues(alpha: 0.15),
                  ),
                ),
              ],
              if (wallet.hasSchedule) ...[
                const SizedBox(height: 14),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: wallet.payouts
                      .map(
                        (payout) => Chip(
                          visualDensity: VisualDensity.compact,
                          backgroundColor: wallet.color.withValues(alpha: 0.10),
                          label: Text(
                            '${payout.scheduleLabel} · ${formatMoney(payout.amount)}',
                            style: theme.textTheme.labelSmall,
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.color,
    this.onTap,
  });

  final String label;
  final String value;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 4),
              Icon(
                Icons.edit_outlined,
                size: 12,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ],
        ),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );

    if (onTap == null) return content;

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Padding(padding: const EdgeInsets.all(2), child: content),
    );
  }
}
