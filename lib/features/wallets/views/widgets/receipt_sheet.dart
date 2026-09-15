import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/utils/moment.dart';
import '../../../../core/utils/month.dart';
import '../../../../core/widgets/check_side_selector.dart';
import '../../../../core/widgets/money_field.dart';
import '../../../../core/widgets/movement_date_picker.dart';
import '../../models/receipt.dart';
import '../../models/wallet.dart';

class ReceiptEdit {
  const ReceiptEdit({
    required this.amount,
    required this.receivedAt,
    this.isDiscarded = false,
  });

  final double amount;
  final DateTime receivedAt;
  final bool isDiscarded;
}

class ReceiptSheet extends StatefulWidget {
  const ReceiptSheet({
    super.key,
    required this.wallet,
    this.receipt,
    this.month,
    this.latestCheckAt,
  });

  static Future<ReceiptEdit?> show(
    BuildContext context, {
    required Wallet wallet,
    Receipt? receipt,
    Month? month,
    DateTime? latestCheckAt,
  }) {
    return showModalBottomSheet<ReceiptEdit>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => ReceiptSheet(
        wallet: wallet,
        receipt: receipt,
        month: month,
        latestCheckAt: latestCheckAt,
      ),
    );
  }

  final Wallet wallet;
  final Receipt? receipt;
  final Month? month;
  final DateTime? latestCheckAt;

  @override
  State<ReceiptSheet> createState() => _ReceiptSheetState();
}

class _ReceiptSheetState extends State<ReceiptSheet> {
  late double _amount = widget.receipt?.amount ?? 0;
  late DateTime _receivedAt = _initialDate;
  late CheckSide _side = _initialSide;
  bool _isMomentTouched = false;

  bool get _keepsStoredMoment =>
      _receipt != null && !_isPredicted && !_isMomentTouched;

  CheckSide get _initialSide {
    final checkedAt = widget.latestCheckAt;
    if (_receipt == null || _isPredicted || checkedAt == null) {
      return CheckSide.after;
    }
    return sideOf(_receivedAt, checkedAt);
  }

  DateTime get _moment => _keepsStoredMoment
      ? _receivedAt
      : stampAround(_receivedAt, checkedAt: widget.latestCheckAt, side: _side);

  /// Confirming a prediction of this month happens when the money shows up,
  /// so it opens on now; one from a month already over keeps its day.
  DateTime get _initialDate {
    final receipt = widget.receipt;
    if (receipt == null) {
      return stampFor((widget.month ?? Month.current()).suggestedDate);
    }
    final now = DateTime.now();
    return receipt.isPredicted && receipt.month == Month.fromDate(now)
        ? now
        : receipt.receivedAt;
  }

  Receipt? get _receipt => widget.receipt;

  bool get _isPredicted => _receipt?.isPredicted ?? false;

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
            if (_isPredicted) ...[
              const SizedBox(height: 4),
              Text(
                'Valor previsto pelo calendário. Corrija para o que caiu de verdade.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 20),
            MoneyField(
              initialValue: _amount,
              label: 'Valor',
              autofocus: _receipt == null,
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
            if (needsCheckSide(_receivedAt, widget.latestCheckAt)) ...[
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
              child: Text(_confirmLabel),
            ),
            if (_receipt != null) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: _discard,
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.error,
                ),
                child: Text(_receipt!.isManual ? 'Remover' : 'Não recebi'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String get _confirmLabel => switch (_receipt) {
    null => 'Registrar entrada',
    _ when _isPredicted => 'Confirmar recebimento',
    _ => 'Salvar entrada',
  };

  void _save() => Navigator.of(
    context,
  ).pop(ReceiptEdit(amount: _amount, receivedAt: _moment));

  void _discard() => Navigator.of(
    context,
  ).pop(ReceiptEdit(amount: _amount, receivedAt: _moment, isDiscarded: true));

  Future<void> _pickDate() async {
    final date = await pickMovementDate(context, _receivedAt);
    if (date == null) return;
    setState(() {
      _receivedAt = stampFor(date);
      _isMomentTouched = true;
    });
  }
}
