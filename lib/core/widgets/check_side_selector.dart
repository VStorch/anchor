import 'package:flutter/material.dart';

import '../utils/moment.dart';

class CheckSideSelector extends StatelessWidget {
  const CheckSideSelector({
    super.key,
    required this.checkedAt,
    required this.value,
    required this.onChanged,
  });

  final DateTime checkedAt;
  final CheckSide value;
  final ValueChanged<CheckSide> onChanged;

  String get _hour => checkedAt.minute == 0
      ? '${checkedAt.hour}h'
      : '${checkedAt.hour}h${checkedAt.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Foi antes ou depois de você informar o saldo ($_hour)?',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 8),
        SegmentedButton<CheckSide>(
          segments: const [
            ButtonSegment(value: CheckSide.before, label: Text('Antes')),
            ButtonSegment(value: CheckSide.after, label: Text('Depois')),
          ],
          selected: {value},
          onSelectionChanged: (selection) => onChanged(selection.single),
        ),
      ],
    );
  }
}
