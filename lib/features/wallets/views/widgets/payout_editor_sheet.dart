import 'package:flutter/material.dart';

import '../../../../core/widgets/day_of_month_picker.dart';
import '../../../../core/widgets/money_field.dart';
import '../../models/payout.dart';

class PayoutDraft {
  const PayoutDraft({
    required this.label,
    required this.amount,
    required this.dayOfMonth,
  });

  final String label;
  final double amount;
  final int dayOfMonth;
}

class PayoutEditorSheet extends StatefulWidget {
  const PayoutEditorSheet({super.key, this.takenDays = const <int>{}});

  static Future<PayoutDraft?> show(
    BuildContext context, {
    required List<Payout> existing,
  }) {
    return showModalBottomSheet<PayoutDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => PayoutEditorSheet(
        takenDays: existing.map((payout) => payout.dayOfMonth).toSet(),
      ),
    );
  }

  final Set<int> takenDays;

  @override
  State<PayoutEditorSheet> createState() => _PayoutEditorSheetState();
}

class _PayoutEditorSheetState extends State<PayoutEditorSheet> {
  final TextEditingController _labelController = TextEditingController();
  double _amount = 0;
  int _day = 5;

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Novo recebimento',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _labelController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Descrição',
                hintText: 'Primeira parcela, adiantamento...',
              ),
            ),
            const SizedBox(height: 16),
            MoneyField(
              initialValue: _amount,
              label: 'Valor recebido',
              onChanged: (value) => setState(() => _amount = value),
            ),
            const SizedBox(height: 20),
            Text(
              'Dia do recebimento',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            DayOfMonthPicker(
              selectedDay: _day,
              highlightedDays: widget.takenDays,
              onDaySelected: (day) => setState(() => _day = day),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _amount > 0
                  ? () => Navigator.of(context).pop(
                      PayoutDraft(
                        label: _labelController.text,
                        amount: _amount,
                        dayOfMonth: _day,
                      ),
                    )
                  : null,
              child: const Text('Adicionar ao calendário'),
            ),
          ],
        ),
      ),
    );
  }
}
