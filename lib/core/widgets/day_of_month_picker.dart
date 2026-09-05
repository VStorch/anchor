import 'package:flutter/material.dart';

class DayOfMonthPicker extends StatelessWidget {
  const DayOfMonthPicker({
    super.key,
    required this.selectedDay,
    required this.onDaySelected,
    this.highlightedDays = const <int>{},
    this.dayCount = 31,
  });

  final int selectedDay;
  final ValueChanged<int> onDaySelected;
  final Set<int> highlightedDays;
  final int dayCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
      ),
      itemCount: dayCount,
      itemBuilder: (context, index) {
        final day = index + 1;
        final isSelected = day == selectedDay;
        final isHighlighted = highlightedDays.contains(day);

        return InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => onDaySelected(day),
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: isSelected
                  ? theme.colorScheme.primary
                  : isHighlighted
                  ? theme.colorScheme.primaryContainer
                  : theme.colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.4,
                    ),
            ),
            child: Text(
              '$day',
              style: theme.textTheme.labelLarge?.copyWith(
                color: isSelected
                    ? theme.colorScheme.onPrimary
                    : isHighlighted
                    ? theme.colorScheme.onPrimaryContainer
                    : theme.colorScheme.onSurfaceVariant,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        );
      },
    );
  }
}
