import 'package:flutter/material.dart';

import '../../../../core/utils/money.dart';
import '../../models/expense_occurrence.dart';
import '../../models/expense_type.dart';

enum ExpenseAction { pay, edit, undoPayment, endRecurring, delete }

class ExpenseActionsSheet extends StatelessWidget {
  const ExpenseActionsSheet({super.key, required this.occurrence});

  static Future<ExpenseAction?> show(
    BuildContext context, {
    required ExpenseOccurrence occurrence,
  }) {
    return showModalBottomSheet<ExpenseAction>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => ExpenseActionsSheet(occurrence: occurrence),
    );
  }

  final ExpenseOccurrence occurrence;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final expense = occurrence.expense;

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  expense.name,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${expense.type.label} · ${formatMoney(occurrence.amount)}'
                  '${occurrence.installmentLabel != null ? ' · parcela ${occurrence.installmentLabel}' : ''}'
                  '${occurrence.isPartlyPaid ? ' · ${formatMoney(occurrence.paidAmount)} pagos' : ''}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.payments_outlined),
            title: Text(
              occurrence.isPaid ? 'Ver pagamentos' : 'Lançar pagamento',
            ),
            subtitle: const Text('Divide entre carteiras e ajusta o valor'),
            onTap: () => Navigator.of(context).pop(ExpenseAction.pay),
          ),
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text('Editar despesa'),
            onTap: () => Navigator.of(context).pop(ExpenseAction.edit),
          ),
          if (occurrence.paidAmount > 0)
            ListTile(
              leading: const Icon(Icons.undo),
              title: const Text('Desfazer pagamentos'),
              onTap: () => Navigator.of(context).pop(ExpenseAction.undoPayment),
            ),
          if (expense.type == ExpenseType.recurring)
            ListTile(
              leading: const Icon(Icons.event_busy_outlined),
              title: const Text('Encerrar neste mês'),
              subtitle: const Text('Deixa de aparecer nos meses seguintes'),
              onTap: () =>
                  Navigator.of(context).pop(ExpenseAction.endRecurring),
            ),
          ListTile(
            leading: Icon(Icons.delete_outline, color: theme.colorScheme.error),
            title: Text(
              'Excluir despesa',
              style: TextStyle(color: theme.colorScheme.error),
            ),
            subtitle: const Text('Remove também o histórico de pagamentos'),
            onTap: () => Navigator.of(context).pop(ExpenseAction.delete),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
