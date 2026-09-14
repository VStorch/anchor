import 'package:flutter/material.dart';

import '../../../../core/utils/money.dart';

/// The money that exists right now, whatever month is on screen.
class TodayCard extends StatelessWidget {
  const TodayCard({
    super.key,
    required this.balance,
    required this.awaitingConfirmation,
    required this.onConfirm,
  });

  final double balance;
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
}
