import 'package:flutter/material.dart';

import '../../../../core/utils/money.dart';
import '../../../budget/models/wallet_summary.dart';

class WalletStrip extends StatelessWidget {
  const WalletStrip({super.key, required this.summaries, required this.onTap});

  final List<WalletSummary> summaries;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.textScalerOf(context).scale(100),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        itemCount: summaries.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) =>
            _WalletChip(summary: summaries[index], onTap: onTap),
      ),
    );
  }
}

class _WalletChip extends StatelessWidget {
  const _WalletChip({required this.summary, required this.onTap});

  final WalletSummary summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final wallet = summary.wallet;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        width: MediaQuery.textScalerOf(context).scale(168),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: wallet.color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(wallet.icon, size: 18, color: wallet.color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    wallet.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              formatMoney(summary.balance),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: summary.balance < 0
                    ? theme.colorScheme.error
                    : theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
