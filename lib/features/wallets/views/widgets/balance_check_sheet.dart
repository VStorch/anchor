import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/utils/moment.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/money_field.dart';
import '../../models/balance_check.dart';
import '../../models/receipt.dart';
import '../../models/wallet.dart';

class BalanceCheckEdit {
  const BalanceCheckEdit({
    required this.amount,
    required this.day,
    this.confirm = const <Receipt>[],
    this.leftPending = const <Receipt>[],
    this.isRemoved = false,
  });

  final double amount;
  final DateTime day;
  final List<Receipt> confirm;
  final List<Receipt> leftPending;
  final bool isRemoved;
}

class BalanceCheckSheet extends StatefulWidget {
  const BalanceCheckSheet({
    super.key,
    required this.wallet,
    required this.calculatedBalance,
    required this.dueUnconfirmed,
    required this.receiptTitle,
    this.check,
    this.latestCheck,
  });

  static Future<BalanceCheckEdit?> show(
    BuildContext context, {
    required Wallet wallet,
    required double calculatedBalance,
    required List<Receipt> Function(DateTime day) dueUnconfirmed,
    required String Function(Receipt receipt) receiptTitle,
    BalanceCheck? check,
    BalanceCheck? latestCheck,
  }) {
    return showModalBottomSheet<BalanceCheckEdit>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => BalanceCheckSheet(
        wallet: wallet,
        calculatedBalance: calculatedBalance,
        dueUnconfirmed: dueUnconfirmed,
        receiptTitle: receiptTitle,
        check: check,
        latestCheck: latestCheck,
      ),
    );
  }

  final Wallet wallet;
  final double calculatedBalance;
  final List<Receipt> Function(DateTime day) dueUnconfirmed;
  final String Function(Receipt receipt) receiptTitle;
  final BalanceCheck? check;
  final BalanceCheck? latestCheck;

  @override
  State<BalanceCheckSheet> createState() => _BalanceCheckSheetState();
}

class _BalanceCheckSheetState extends State<BalanceCheckSheet> {
  late double _amount = widget.check?.amount ?? widget.calculatedBalance;
  late DateTime _day = widget.check?.checkedAt ?? DateTime.now();
  final Set<int?> _notArrived = <int?>{};

  List<Receipt> get _due => widget.dueUnconfirmed(_day);

  BalanceCheck? get _supersededBy {
    final check = widget.check;
    final latest = widget.latestCheck;
    if (check == null || latest == null || latest.id == check.id) return null;
    return latest;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final due = _due;

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
              'Saldo de ${widget.wallet.name}',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'O que tiver data até esse momento já está dentro do valor '
              'informado.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (_supersededBy case final latest?) ...[
              const SizedBox(height: 12),
              Text(
                'Esse não é o saldo mais recente '
                '(${DateFormat('dd/MM').format(latest.checkedAt)}): mudar o '
                'valor não altera o saldo de hoje.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: 20),
            MoneyField(
              initialValue: _amount,
              label: 'Quanto tem hoje?',
              autofocus: widget.check == null,
              allowNegative: true,
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
              title: Text('Em ${DateFormat.yMMMMd('pt_BR').format(_day)}'),
              trailing: const Icon(Icons.edit_calendar_outlined),
              onTap: _pickDay,
            ),
            const SizedBox(height: 12),
            Text(
              'O app calcula ${formatMoney(widget.calculatedBalance)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            for (final receipt in due)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: !_notArrived.contains(receipt.id),
                onChanged: (arrived) => setState(
                  () => arrived ?? false
                      ? _notArrived.remove(receipt.id)
                      : _notArrived.add(receipt.id),
                ),
                title: Text(
                  '${widget.receiptTitle(receipt)} de '
                  '${DateFormat('dd/MM').format(receipt.receivedAt)} '
                  '(${formatMoney(receipt.amount)}) já caiu',
                ),
              ),
            const SizedBox(height: 24),
            FilledButton(onPressed: _save, child: const Text('Salvar saldo')),
            if (widget.check != null) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: _remove,
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

  void _save() => Navigator.of(context).pop(
    BalanceCheckEdit(
      amount: _amount,
      day: _day,
      confirm: _due
          .where((receipt) => !_notArrived.contains(receipt.id))
          .toList(),
      leftPending: _due
          .where((receipt) => _notArrived.contains(receipt.id))
          .toList(),
    ),
  );

  void _remove() => Navigator.of(
    context,
  ).pop(BalanceCheckEdit(amount: _amount, day: _day, isRemoved: true));

  Future<void> _pickDay() async {
    final today = DateTime.now();
    final day = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime(today.year - 5),
      lastDate: today,
    );
    if (day == null) return;
    setState(() => _day = isSameDay(day, today) ? today : day);
  }
}
