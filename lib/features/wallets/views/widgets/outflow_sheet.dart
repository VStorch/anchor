import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/widgets/money_field.dart';
import '../../models/outflow.dart';
import '../../models/wallet.dart';

class OutflowEdit {
  const OutflowEdit({
    required this.description,
    required this.amount,
    required this.spentAt,
    this.isDiscarded = false,
  });

  final String description;
  final double amount;
  final DateTime spentAt;
  final bool isDiscarded;
}

class OutflowSheet extends StatefulWidget {
  const OutflowSheet({super.key, required this.wallet, this.outflow});

  static Future<OutflowEdit?> show(
    BuildContext context, {
    required Wallet wallet,
    Outflow? outflow,
  }) {
    return showModalBottomSheet<OutflowEdit>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => OutflowSheet(wallet: wallet, outflow: outflow),
    );
  }

  final Wallet wallet;
  final Outflow? outflow;

  @override
  State<OutflowSheet> createState() => _OutflowSheetState();
}

class _OutflowSheetState extends State<OutflowSheet> {
  late double _amount = widget.outflow?.amount ?? 0;
  late String _description = widget.outflow?.description ?? '';
  late DateTime _spentAt = widget.outflow?.spentAt ?? DateTime.now();

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
              'Gasto em ${widget.wallet.name}',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 20),
            MoneyField(
              initialValue: _amount,
              label: 'Valor',
              autofocus: widget.outflow == null,
              onChanged: (value) => setState(() => _amount = value),
            ),
            const SizedBox(height: 16),
            TextFormField(
              initialValue: _description,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'No que foi',
                hintText: 'Mercado, almoço, farmácia...',
              ),
              onChanged: (value) => _description = value,
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              tileColor: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.4,
              ),
              leading: const Icon(Icons.event_outlined),
              title: Text(DateFormat.yMMMMd('pt_BR').format(_spentAt)),
              trailing: const Icon(Icons.edit_calendar_outlined),
              onTap: _pickDate,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _amount > 0 ? _save : null,
              child: Text(
                widget.outflow == null ? 'Registrar gasto' : 'Salvar gasto',
              ),
            ),
            if (widget.outflow != null) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: _discard,
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.error,
                ),
                child: const Text('Remover'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _save() => Navigator.of(context).pop(_edit());

  void _discard() => Navigator.of(context).pop(
    OutflowEdit(
      description: _description,
      amount: _amount,
      spentAt: _spentAt,
      isDiscarded: true,
    ),
  );

  OutflowEdit _edit() => OutflowEdit(
    description: _description,
    amount: _amount,
    spentAt: _spentAt,
  );

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _spentAt,
      firstDate: DateTime(DateTime.now().year - 5),
      lastDate: DateTime(DateTime.now().year + 5),
    );
    if (date != null) setState(() => _spentAt = date);
  }
}
