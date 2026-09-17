import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../utils/month.dart';
import 'dismiss_focus.dart';

class MonthPickerSheet extends StatefulWidget {
  const MonthPickerSheet({super.key, required this.initialMonth, this.title});

  static Future<Month?> show(
    BuildContext context, {
    required Month initialMonth,
    String? title,
  }) {
    releaseFocus();
    return showModalBottomSheet<Month>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) =>
          MonthPickerSheet(initialMonth: initialMonth, title: title),
    );
  }

  final Month initialMonth;
  final String? title;

  @override
  State<MonthPickerSheet> createState() => _MonthPickerSheetState();
}

class _MonthPickerSheetState extends State<MonthPickerSheet> {
  late int _year = widget.initialMonth.year;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.title ?? 'Escolha o mês',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton.filledTonal(
                onPressed: () => setState(() => _year--),
                icon: const Icon(Icons.chevron_left),
              ),
              Text(
                '$_year',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              IconButton.filledTonal(
                onPressed: () => setState(() => _year++),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 2.2,
            ),
            itemCount: 12,
            itemBuilder: (context, index) {
              final month = Month(_year, index + 1);
              final isSelected = month == widget.initialMonth;

              return InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => Navigator.of(context).pop(month),
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: isSelected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.surfaceContainerHighest.withValues(
                            alpha: 0.4,
                          ),
                  ),
                  child: Text(
                    toBeginningOfSentenceCase(
                      DateFormat.MMMM('pt_BR').format(month.firstDay),
                    )!,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: isSelected
                          ? theme.colorScheme.onPrimary
                          : theme.colorScheme.onSurfaceVariant,
                      fontWeight: isSelected ? FontWeight.w700 : null,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
