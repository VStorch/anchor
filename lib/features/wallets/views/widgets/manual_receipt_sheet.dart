import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/widgets/money_field.dart';
import '../../models/wallet.dart';

class ManualReceipt {
  const ManualReceipt({required this.amount, required this.receivedAt});

  final double amount;
  final DateTime receivedAt;
}

class ManualReceiptSheet extends StatefulWidget {
  const ManualReceiptSheet({super.key, required this.wallet});

  static Future<ManualReceipt?> show(
    BuildContext context, {
    required Wallet wallet,
  }) {
    return showModalBottomSheet<ManualReceipt>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => ManualReceiptSheet(wallet: wallet),
    );
  }

  final Wallet wallet;

  @override
  State<ManualReceiptSheet> createState() => _ManualReceiptSheetState();
}

class _ManualReceiptSheetState extends State<ManualReceiptSheet> {
  double _amount = 0;
  DateTime _receivedAt = DateTime.now();

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
              'Entrada em ${widget.wallet.name}',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Use para valores fora do calendário, como um extra ou bônus',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            MoneyField(
              initialValue: _amount,
              label: 'Valor',
              autofocus: true,
              onChanged: (value) => setState(() => _amount = value),
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
              title: Text(DateFormat.yMMMMd('pt_BR').format(_receivedAt)),
              trailing: const Icon(Icons.edit_calendar_outlined),
              onTap: _pickDate,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _amount > 0
                  ? () => Navigator.of(context).pop(
                      ManualReceipt(amount: _amount, receivedAt: _receivedAt),
                    )
                  : null,
              child: const Text('Registrar entrada'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _receivedAt,
      firstDate: DateTime(DateTime.now().year - 5),
      lastDate: DateTime(DateTime.now().year + 5),
    );
    if (date != null) setState(() => _receivedAt = date);
  }
}
