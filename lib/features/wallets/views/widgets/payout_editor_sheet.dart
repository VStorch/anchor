import 'package:flutter/material.dart';

import '../../../../core/widgets/day_of_month_picker.dart';
import '../../../../core/widgets/money_field.dart';
import '../../models/payout.dart';
import '../../models/payout_schedule.dart';

class PayoutDraft {
  const PayoutDraft({
    required this.label,
    required this.amount,
    required this.day,
    required this.schedule,
  });

  final String label;
  final double amount;
  final int day;
  final PayoutSchedule schedule;
}

class PayoutEditorSheet extends StatefulWidget {
  const PayoutEditorSheet({
    super.key,
    this.payout,
    this.takenDays = const <int>{},
  });

  static Future<PayoutDraft?> show(
    BuildContext context, {
    required List<Payout> existing,
    Payout? payout,
  }) {
    return showModalBottomSheet<PayoutDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => PayoutEditorSheet(
        payout: payout,
        takenDays: existing
            .where((other) => other != payout)
            .map((other) => other.day)
            .toSet(),
      ),
    );
  }

  final Payout? payout;
  final Set<int> takenDays;

  @override
  State<PayoutEditorSheet> createState() => _PayoutEditorSheetState();
}

class _PayoutEditorSheetState extends State<PayoutEditorSheet> {
  late final TextEditingController _labelController = TextEditingController(
    text: widget.payout?.label ?? '',
  );
  late double _amount = widget.payout?.amount ?? 0;
  late int? _day = widget.payout?.day;
  late PayoutSchedule _schedule =
      widget.payout?.schedule ?? PayoutSchedule.dayOfMonth;

  bool get _isEditing => widget.payout != null;

  int get _dayCount => _schedule.isBusinessDay ? Payout.maxBusinessDay : 31;

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
              _isEditing ? 'Editar recebimento' : 'Novo recebimento',
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
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Dia fixo')),
                ButtonSegment(value: true, label: Text('Dia útil')),
              ],
              selected: {_schedule.isBusinessDay},
              onSelectionChanged: (selection) => _changeSchedule(
                selection.first
                    ? PayoutSchedule.businessDay
                    : PayoutSchedule.dayOfMonth,
              ),
            ),
            if (_schedule.isBusinessDay)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Contar sábado (prazo da CLT)'),
                value: _schedule == PayoutSchedule.businessDaySaturday,
                onChanged: (countSaturday) => _changeSchedule(
                  countSaturday
                      ? PayoutSchedule.businessDaySaturday
                      : PayoutSchedule.businessDay,
                ),
              ),
            const SizedBox(height: 20),
            Text(
              _day == null
                  ? 'Em que dia cai?'
                  : _schedule.isBusinessDay
                  ? 'Cai no $_dayº dia útil'
                  : 'Cai no dia $_day',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            DayOfMonthPicker(
              selectedDay: _day,
              dayCount: _dayCount,
              highlightedDays: widget.takenDays,
              onDaySelected: (day) => setState(() => _day = day),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _amount > 0 && _day != null ? _submit : null,
              child: Text(
                _day == null
                    ? 'Escolha o dia'
                    : _isEditing
                    ? 'Salvar recebimento'
                    : 'Adicionar ao calendário',
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _changeSchedule(PayoutSchedule schedule) {
    setState(() {
      _schedule = schedule;
      if ((_day ?? 0) > _dayCount) _day = _dayCount;
    });
  }

  void _submit() => Navigator.of(context).pop(
    PayoutDraft(
      label: _labelController.text,
      amount: _amount,
      day: _day!,
      schedule: _schedule,
    ),
  );
}
