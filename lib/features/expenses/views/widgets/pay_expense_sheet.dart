import 'package:flutter/material.dart';

import '../../../../core/utils/money.dart';
import '../../../../core/widgets/money_field.dart';
import '../../../budget/models/wallet_summary.dart';
import '../../models/expense_occurrence.dart';

class PaymentChoice {
  const PaymentChoice({required this.walletId, required this.amount});

  final int? walletId;
  final double amount;
}

class PayExpenseSheet extends StatefulWidget {
  const PayExpenseSheet({
    super.key,
    required this.occurrence,
    required this.walletSummaries,
  });

  static Future<PaymentChoice?> show(
    BuildContext context, {
    required ExpenseOccurrence occurrence,
    required List<WalletSummary> walletSummaries,
  }) {
    return showModalBottomSheet<PaymentChoice>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => PayExpenseSheet(
        occurrence: occurrence,
        walletSummaries: walletSummaries,
      ),
    );
  }

  final ExpenseOccurrence occurrence;
  final List<WalletSummary> walletSummaries;

  @override
  State<PayExpenseSheet> createState() => _PayExpenseSheetState();
}

class _PayExpenseSheetState extends State<PayExpenseSheet> {
  late double _amount = widget.occurrence.amount;
  late int? _walletId = widget.occurrence.walletId;

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
              'Pagar ${widget.occurrence.expense.name}',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Vence em ${widget.occurrence.dueDate.day} de ${widget.occurrence.month.label}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            MoneyField(
              initialValue: _amount,
              label: 'Valor pago',
              onChanged: (value) => setState(() => _amount = value),
            ),
            const SizedBox(height: 20),
            Text(
              'Pago com',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            if (widget.walletSummaries.isEmpty)
              Text(
                'Nenhuma carteira cadastrada.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            else
              ...widget.walletSummaries.map(_walletOption),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _amount > 0
                  ? () => Navigator.of(
                      context,
                    ).pop(PaymentChoice(walletId: _walletId, amount: _amount))
                  : null,
              child: const Text('Confirmar pagamento'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _walletOption(WalletSummary summary) {
    final wallet = summary.wallet;
    final isSelected = _walletId == wallet.id;
    final isShort = summary.balance < _amount;

    return RadioListTile<int?>(
      value: wallet.id,
      groupValue: _walletId,
      onChanged: (value) => setState(() => _walletId = value),
      contentPadding: EdgeInsets.zero,
      title: Text(wallet.name),
      subtitle: Text(
        '${formatMoney(summary.balance)} disponível'
        '${isShort && isSelected ? ' · saldo insuficiente' : ''}',
      ),
      secondary: CircleAvatar(
        backgroundColor: wallet.color.withValues(alpha: 0.16),
        child: Icon(wallet.icon, color: wallet.color, size: 20),
      ),
      selected: isSelected,
    );
  }
}
