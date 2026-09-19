import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/utils/moment.dart';
import '../../../../core/widgets/check_side_selector.dart';
import '../../../../core/widgets/money_field.dart';
import '../../../../core/widgets/movement_sheet_title.dart';
import '../../../../core/widgets/movement_date_picker.dart';
import '../../../wallets/models/balance_check.dart';
import '../../../wallets/models/wallet.dart';
import '../../../../core/utils/money.dart';
import '../../models/expense_occurrence.dart';
import '../../models/expense_payment.dart';
import '../../models/expense_type.dart';
import '../../models/payable.dart';
import '../../viewmodels/expenses_view_model.dart';

class PayEdit {
  const PayEdit({
    required this.origin,
    required this.amount,
    required this.paidAt,
    this.closesMonth = false,
  });

  final PaymentOrigin origin;
  final double amount;
  final DateTime paidAt;

  /// Less than the bill was paid because the bill itself was smaller: the
  /// month amount becomes what was paid in all.
  final bool closesMonth;
}

/// Where the money came from, how much and when. Without [amount] the sheet
/// only asks for the origin and the day (an invoice pays what is left).
///
/// With a [payable] and [checkFor], a wallet whose balance was informed after
/// the bill fell due asks whether the money had already left before the sheet
/// can save, unless the day was picked by hand. On the day of the chosen
/// wallet's latest check ([latestCheckAtOf]) it asks which side of the check
/// the payment falls; an [isEdit] left untouched keeps its instant.
class PaySheet extends StatefulWidget {
  const PaySheet({
    super.key,
    required this.title,
    required this.wallets,
    required this.origin,
    required this.paidAt,
    this.amount,
    this.payable,
    this.checkFor,
    this.latestCheckAtOf,
    this.isEdit = false,
  });

  static Future<PayEdit?> show(
    BuildContext context, {
    required String title,
    required List<Wallet> wallets,
    required PaymentOrigin origin,
    required DateTime paidAt,
    double? amount,
    Payable? payable,
    BalanceCheck? Function(PaymentOrigin origin)? checkFor,
    DateTime? Function(int walletId)? latestCheckAtOf,
    bool isEdit = false,
  }) {
    return showModalBottomSheet<PayEdit>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => PaySheet(
        title: title,
        wallets: wallets,
        origin: origin,
        paidAt: paidAt,
        amount: amount,
        payable: payable,
        checkFor: checkFor,
        latestCheckAtOf: latestCheckAtOf,
        isEdit: isEdit,
      ),
    );
  }

  final String title;
  final List<Wallet> wallets;
  final PaymentOrigin origin;
  final DateTime paidAt;
  final double? amount;
  final Payable? payable;
  final BalanceCheck? Function(PaymentOrigin origin)? checkFor;
  final DateTime? Function(int walletId)? latestCheckAtOf;
  final bool isEdit;

  @override
  State<PaySheet> createState() => _PaySheetState();
}

class _PaySheetState extends State<PaySheet> {
  late PaymentOrigin _origin = widget.origin;
  late double _amount = widget.amount ?? 0;
  late DateTime _paidAt = widget.paidAt;
  bool _dayPicked = false;
  bool _sidePicked = false;
  bool? _alreadyOut;
  bool _closesMonth = true;
  late CheckSide _side = _initialSide;

  CheckSide get _initialSide {
    final checkedAt = _latestCheckAt;
    if (!widget.isEdit || checkedAt == null) return CheckSide.after;
    return sideOf(widget.paidAt, checkedAt);
  }

  DateTime? get _latestCheckAt =>
      _isOutside ? null : widget.latestCheckAtOf?.call(_origin.walletId!);

  bool get _asksSide =>
      _pendingCheck == null && needsCheckSide(_paidAt, _latestCheckAt);

  DateTime get _moment {
    if (_pendingCheck != null) return _paidAt;
    if (widget.isEdit && !_dayPicked && !_sidePicked) return _paidAt;
    return stampAround(_paidAt, checkedAt: _latestCheckAt, side: _side);
  }

  bool get _asksAmount => widget.amount != null;

  /// A loose bill paid with less than it owes: was the bill smaller, or is
  /// this a part? Only a new payment of a recurring or one-off bill off any
  /// card asks: a purchase or a parcel costs what was agreed, so less is a
  /// part.
  ExpenseOccurrence? get _partlyPaid {
    if (widget.isEdit || !_asksAmount || _amount <= 0) return null;
    final payable = widget.payable;
    if (payable is! ExpenseOccurrence || payable.offRule) return null;
    final expense = payable.expense;
    if (expense.cardId != null || expense.type == ExpenseType.installment) {
      return null;
    }
    return coversAmount(_amount, payable.remaining) ? null : payable;
  }

  bool get _isOutside => _origin.outside || _origin.walletId == null;

  BalanceCheck? get _pendingCheck {
    if (_dayPicked || _isOutside || widget.payable == null) return null;
    return widget.checkFor?.call(_origin);
  }

  bool get _canSave =>
      (!_asksAmount || _amount > 0) &&
      (_pendingCheck == null || _alreadyOut != null);

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
            MovementSheetTitle(widget.title, isIncome: false),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final wallet in widget.wallets)
                  ChoiceChip(
                    label: Text(wallet.name),
                    selected: !_isOutside && _origin.walletId == wallet.id,
                    onSelected: (_) =>
                        _changeOrigin((walletId: wallet.id, outside: false)),
                  ),
                ChoiceChip(
                  label: const Text('Outro dinheiro'),
                  selected: _isOutside,
                  onSelected: (_) =>
                      _changeOrigin((walletId: null, outside: true)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              _isOutside ? 'Não mexe no saldo' : 'Sai de ${_walletName()}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (_asksAmount) ...[
              const SizedBox(height: 16),
              MoneyField(
                initialValue: _amount,
                label: 'Valor pago',
                onChanged: (value) => setState(() => _amount = value),
              ),
            ],
            if (_partlyPaid case final occurrence?) ...[
              const SizedBox(height: 12),
              RadioGroupChoice(
                value: _closesMonth,
                onChanged: (value) => setState(() => _closesMonth = value),
                options: {
                  true:
                      'A conta deste mês foi '
                      '${formatMoney(roundCents(occurrence.paidAmount + _amount))}',
                  false:
                      'Paguei só uma parte (falta '
                      '${formatMoney(roundCents(occurrence.remaining - _amount))})',
                },
              ),
            ],
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
              title: Text(
                'Pago em ${DateFormat.yMMMMd('pt_BR').format(_paidAt)}',
              ),
              trailing: const Icon(Icons.edit_calendar_outlined),
              onTap: _pickDate,
            ),
            if (_pendingCheck case final check?) ...[
              const SizedBox(height: 16),
              Text(
                checkCoveringQuestion(widget.payable!, check),
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Já tinha saído'),
                    selected: _alreadyOut == true,
                    onSelected: (_) => _answer(check, alreadyOut: true),
                  ),
                  ChoiceChip(
                    label: const Text('Paguei agora'),
                    selected: _alreadyOut == false,
                    onSelected: (_) => _answer(check, alreadyOut: false),
                  ),
                ],
              ),
            ],
            if (_asksSide) ...[
              const SizedBox(height: 16),
              CheckSideSelector(
                checkedAt: _latestCheckAt!,
                value: _side,
                onChanged: (side) => setState(() {
                  _side = side;
                  _sidePicked = true;
                }),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: _canSave ? _save : null,
                    child: const Text('Lançar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _walletName() {
    for (final wallet in widget.wallets) {
      if (wallet.id == _origin.walletId) return wallet.name;
    }
    return 'Carteira';
  }

  void _save() => Navigator.of(context).pop(
    PayEdit(
      origin: _isOutside ? (walletId: null, outside: true) : _origin,
      amount: _amount,
      paidAt: _moment,
      closesMonth: _partlyPaid != null && _closesMonth,
    ),
  );

  void _changeOrigin(PaymentOrigin origin) => setState(() {
    _origin = origin;
    _alreadyOut = null;
    if (!_dayPicked) _paidAt = widget.paidAt;
  });

  void _answer(BalanceCheck check, {required bool alreadyOut}) => setState(() {
    _alreadyOut = alreadyOut;
    _paidAt = alreadyOut
        ? widget.payable!.paidBefore(check.checkedAt)
        : DateTime.now();
  });

  Future<void> _pickDate() async {
    final date = await pickMovementDate(context, _paidAt);
    if (date == null) return;
    setState(() {
      _paidAt = stampFor(date);
      _dayPicked = true;
    });
  }
}

/// Two answers, one of them picked, each a full-width 48dp row.
class RadioGroupChoice extends StatelessWidget {
  const RadioGroupChoice({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final bool value;
  final Map<bool, String> options;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final entry in options.entries)
          RadioListTile<bool>(
            contentPadding: EdgeInsets.zero,
            value: entry.key,
            groupValue: value,
            onChanged: (picked) {
              if (picked != null) onChanged(picked);
            },
            title: Text(entry.value),
          ),
      ],
    );
  }
}

/// Whether the amount had already left when the balance was informed: a bill
/// that fell due earlier is asked by day, one due today by the hour.
String checkCoveringQuestion(Payable payable, BalanceCheck check) {
  if (payable.dueState.isDueToday) {
    return 'Já tinha saído do saldo das '
        '${DateFormat("H'h'mm").format(check.checkedAt)}?';
  }
  return 'Já tinha saído do saldo de '
      '${DateFormat('dd/MM').format(check.checkedAt)}?';
}

/// The day a one-tap payment is recorded with. When the wallet's balance was
/// informed after the bill fell due, only the user knows whether that amount
/// was already without it; null means the question was dismissed.
Future<DateTime?> choosePaidAt(
  BuildContext context, {
  required ExpensesViewModel viewModel,
  required Payable payable,
  required int? walletId,
}) async {
  final check = viewModel.checkCoveringDue(payable, walletId);
  if (check == null) return payable.suggestedPaidAt(DateTime.now());

  final alreadyOut = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      content: Text(checkCoveringQuestion(payable, check)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Paguei agora'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Já tinha saído'),
        ),
      ],
    ),
  );

  if (alreadyOut == null) return null;
  return alreadyOut
      ? viewModel.paidBeforeCheck(payable, check)
      : DateTime.now();
}
