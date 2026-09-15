import 'package:flutter/material.dart';

import '../utils/month.dart';

class MonthSwitcher extends StatelessWidget {
  const MonthSwitcher({
    super.key,
    required this.month,
    required this.onPrevious,
    required this.onNext,
    this.onToday,
  });

  final Month month;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback? onToday;

  bool get canGoToToday => onToday != null && !month.isCurrent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        IconButton.filledTonal(
          onPressed: onPrevious,
          icon: const Icon(Icons.chevron_left),
          tooltip: 'Mês anterior',
        ),
        Expanded(
          child: Semantics(
            header: true,
            button: canGoToToday,
            label: month.label,
            hint: canGoToToday ? 'Voltar para o mês atual' : null,
            excludeSemantics: true,
            child: InkWell(
              onTap: canGoToToday ? onToday : null,
              borderRadius: BorderRadius.circular(12),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      month.label,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (canGoToToday)
                      Text(
                        'Voltar para o mês atual',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        IconButton.filledTonal(
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right),
          tooltip: 'Próximo mês',
        ),
      ],
    );
  }
}
