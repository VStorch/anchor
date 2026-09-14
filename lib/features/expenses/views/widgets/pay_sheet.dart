import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/utils/moment.dart';
import '../../../../core/widgets/money_field.dart';
import '../../../../core/widgets/movement_date_picker.dart';
import '../../../wallets/models/wallet.dart';
import '../../models/expense_payment.dart';
import '../../models/payable.dart';
import '../../viewmodels/expenses_view_model.dart';

class PayEdit {
  const PayEdit({
    required this.origin,
    required this.amount,
    required this.paidAt,
  });

  final PaymentOrigin origin;
  final double amount;
  final DateTime paidAt;
}

/// Where the money came from, how much and when. Without [amount] the sheet
/// only asks for the origin and the day (an invoice pays what is left).
class PaySheet extends StatefulWidget {
  const PaySheet({
    super.key,
    required this.title,
    required this.wallets,
    required this.origin,
    required this.paidAt,
    this.amount,
  });

  static Future<PayEdit?> show(
    BuildContext context, {
    required String title,
    required List<Wallet> wallets,
    required PaymentOrigin origin,
    required DateTime paidAt,
    double? amount,
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
      ),
    );
  }

  final String title;
  final List<Wallet> wallets;
  final PaymentOrigin origin;
  final DateTime paidAt;
  final double? amount;

  @override
  State<PaySheet> createState() => _PaySheetState();
}

class _PaySheetState extends State<PaySheet> {
  late PaymentOrigin _origin = widget.origin;
  late double _amount = widget.amount ?? 0;
  late DateTime _paidAt = widget.paidAt;

  bool get _asksAmount => widget.amount != null;

  bool get _isOutside => _origin.outside || _origin.walletId == null;

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
              widget.title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final wallet in widget.wallets)
                  ChoiceChip(
                    label: Text(wallet.name),
                    selected: !_isOutside && _origin.walletId == wallet.id,
                    onSelected: (_) => setState(
                      () => _origin = (walletId: wallet.id, outside: false),
                    ),
                  ),
                ChoiceChip(
                  label: const Text('Outro dinheiro'),
                  selected: _isOutside,
                  onSelected: (_) =>
                      setState(() => _origin = (walletId: null, outside: true)),
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
                    onPressed: !_asksAmount || _amount > 0 ? _save : null,
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
      paidAt: _paidAt,
    ),
  );

  Future<void> _pickDate() async {
    final date = await pickMovementDate(context, _paidAt);
    if (date != null) setState(() => _paidAt = stampFor(date));
  }
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

  final walletName = viewModel.snapshot.walletById(walletId)?.name ?? '';
  final alreadyOut = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      content: Text(
        'Essa conta venceu antes de você informar o saldo de $walletName '
        '(${DateFormat('dd/MM').format(check.checkedAt)}). '
        'O valor já tinha saído?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Não, paguei agora'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Sim, já estava descontado'),
        ),
      ],
    ),
  );

  if (alreadyOut == null) return null;
  return alreadyOut
      ? viewModel.paidBeforeCheck(payable, check)
      : DateTime.now();
}
