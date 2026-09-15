import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/widgets/day_of_month_picker.dart';

class StepHeader extends StatelessWidget {
  const StepHeader({super.key, required this.title, this.message});

  final String title;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(
              title,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: 8),
            Text(
              message!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A question answered with two buttons and no answer picked beforehand.
class YesNoQuestion extends StatelessWidget {
  const YesNoQuestion({
    super.key,
    required this.question,
    required this.value,
    required this.onChanged,
    this.yes = 'Sim',
    this.no = 'Não',
  });

  final String question;
  final bool? value;
  final ValueChanged<bool> onChanged;
  final String yes;
  final String no;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          question,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        SegmentedButton<bool>(
          showSelectedIcon: false,
          emptySelectionAllowed: true,
          segments: [
            ButtonSegment(value: true, label: Text(yes)),
            ButtonSegment(value: false, label: Text(no)),
          ],
          selected: {?value},
          onSelectionChanged: (selection) {
            if (selection.isNotEmpty) onChanged(selection.single);
          },
        ),
      ],
    );
  }
}

/// A day of the month picked in a sheet, so a form with several days stays
/// short and every day cell keeps its full size.
class DayButton extends StatelessWidget {
  const DayButton({
    super.key,
    required this.label,
    required this.sheetTitle,
    required this.day,
    required this.onPicked,
    this.dayCount = 31,
  });

  final String label;
  final String sheetTitle;
  final int? day;
  final ValueChanged<int> onPicked;
  final int dayCount;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        alignment: Alignment.centerLeft,
      ),
      onPressed: () => _pick(context),
      icon: const Icon(Icons.event_outlined),
      label: Text(day == null ? 'Escolha o dia' : label),
    );
  }

  Future<void> _pick(BuildContext context) async {
    final picked = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              sheetTitle,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            DayOfMonthPicker(
              selectedDay: day,
              dayCount: dayCount,
              onDaySelected: (day) => Navigator.of(context).pop(day),
            ),
          ],
        ),
      ),
    );
    if (picked != null) onPicked(picked);
  }
}

/// "ter, 8/set".
String weekdayAndDay(DateTime date) =>
    DateFormat('EEE, d/MMM', 'pt_BR').format(date).replaceAll('.', '');

/// "8/set".
String dayAndMonth(DateTime date) =>
    DateFormat('d/MMM', 'pt_BR').format(date).replaceAll('.', '');

String monthName(DateTime date) => DateFormat.MMMM('pt_BR').format(date);
