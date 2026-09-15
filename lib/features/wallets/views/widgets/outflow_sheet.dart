import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/utils/moment.dart';
import '../../../../core/utils/month.dart';
import '../../../../core/widgets/check_side_selector.dart';
import '../../../../core/widgets/money_field.dart';
import '../../../../core/widgets/movement_sheet_title.dart';
import '../../../../core/widgets/movement_date_picker.dart';
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
  const OutflowSheet({
    super.key,
    required this.wallet,
    this.outflow,
    this.month,
    this.latestCheckAt,
  });

  static Future<OutflowEdit?> show(
    BuildContext context, {
    required Wallet wallet,
    Outflow? outflow,
    Month? month,
    DateTime? latestCheckAt,
  }) {
    return showModalBottomSheet<OutflowEdit>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => OutflowSheet(
        wallet: wallet,
        outflow: outflow,
        month: month,
        latestCheckAt: latestCheckAt,
      ),
    );
  }

  final Wallet wallet;
  final Outflow? outflow;
  final Month? month;
  final DateTime? latestCheckAt;

  @override
  State<OutflowSheet> createState() => _OutflowSheetState();
}

class _OutflowSheetState extends State<OutflowSheet> {
  late double _amount = widget.outflow?.amount ?? 0;
  late String _description = widget.outflow?.description ?? '';
  late DateTime _spentAt =
      widget.outflow?.spentAt ??
      stampFor((widget.month ?? Month.current()).suggestedDate);
  late CheckSide _side = _initialSide;
  bool _isMomentTouched = false;

  CheckSide get _initialSide {
    final checkedAt = widget.latestCheckAt;
    final outflow = widget.outflow;
    if (outflow == null || checkedAt == null) return CheckSide.after;
    return sideOf(outflow.spentAt, checkedAt);
  }

  DateTime get _moment => widget.outflow != null && !_isMomentTouched
      ? _spentAt
      : stampAround(_spentAt, checkedAt: widget.latestCheckAt, side: _side);

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
            MovementSheetTitle(
              'Gasto em ${widget.wallet.name}',
              isIncome: false,
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
            if (needsCheckSide(_spentAt, widget.latestCheckAt)) ...[
              const SizedBox(height: 16),
              CheckSideSelector(
                checkedAt: widget.latestCheckAt!,
                value: _side,
                onChanged: (side) => setState(() {
                  _side = side;
                  _isMomentTouched = true;
                }),
              ),
            ],
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
      spentAt: _moment,
      isDiscarded: true,
    ),
  );

  OutflowEdit _edit() =>
      OutflowEdit(description: _description, amount: _amount, spentAt: _moment);

  Future<void> _pickDate() async {
    final date = await pickMovementDate(context, _spentAt);
    if (date == null) return;
    setState(() {
      _spentAt = stampFor(date);
      _isMomentTouched = true;
    });
  }
}
