import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../core/utils/money.dart';
import '../../../../core/utils/month.dart';
import '../../../../core/widgets/money_field.dart';
import '../../../wallets/models/wallet.dart';
import '../../models/expense.dart';
import '../../models/expense_occurrence.dart';
import '../../models/expense_payment.dart';
import '../../models/payable.dart';
import '../../viewmodels/expenses_view_model.dart';
import '../expense_form_page.dart';
import 'pay_sheet.dart';

class ExpenseLedgerSheet extends StatefulWidget {
  const ExpenseLedgerSheet({
    super.key,
    required this.expenseId,
    required this.month,
  });

  static Future<void> show(
    BuildContext context, {
    required ExpenseOccurrence occurrence,
  }) {
    final viewModel = context.read<ExpensesViewModel>();

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => ChangeNotifierProvider<ExpensesViewModel>.value(
        value: viewModel,
        child: ExpenseLedgerSheet(
          expenseId: occurrence.expense.id!,
          month: occurrence.month,
        ),
      ),
    );
  }

  final int expenseId;

  /// The month the sheet was opened on, which the ledger keeps reading even
  /// when it belongs to an invoice outside the month on screen.
  final Month month;

  @override
  State<ExpenseLedgerSheet> createState() => _ExpenseLedgerSheetState();
}

class _ExpenseLedgerSheetState extends State<ExpenseLedgerSheet> {
  bool _isEditingAmount = false;

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<ExpensesViewModel>();
    final occurrence = viewModel.occurrenceIn(widget.expenseId, widget.month);
    if (occurrence == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final wallets = viewModel.snapshot.wallets;

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
            Row(
              children: [
                Expanded(
                  child: Text(
                    occurrence.expense.name,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _ExpenseMenu(occurrence: occurrence),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              occurrence.offRule
                  ? 'Fora da regra atual'
                  : 'Vence ${DateFormat('dd/MM').format(occurrence.dueDate)}'
                        '${occurrence.installmentLabel != null ? ' · parcela ${occurrence.installmentLabel}' : ''}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            if (!occurrence.offRule) ...[
              _monthAmount(context, viewModel, occurrence),
              const SizedBox(height: 20),
            ],
            Text(
              'Pagamentos',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            if (occurrence.payments.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Nada lançado ainda.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ...occurrence.payments.map(
              (payment) => _paymentLine(context, viewModel, wallets, payment),
            ),
            const SizedBox(height: 12),
            _footer(context, viewModel, occurrence, wallets),
          ],
        ),
      ),
    );
  }

  Widget _monthAmount(
    BuildContext context,
    ExpensesViewModel viewModel,
    ExpenseOccurrence occurrence,
  ) {
    final theme = Theme.of(context);

    if (_isEditingAmount) {
      return _AmountEditor(
        key: ValueKey('amount-${occurrence.amount}'),
        initialAmount: occurrence.amount,
        canReset: occurrence.hasCustomAmount,
        onReset: () async {
          await viewModel.resetMonthAmount(occurrence);
          if (mounted) setState(() => _isEditingAmount = false);
        },
        onCancel: () => setState(() => _isEditingAmount = false),
        onConfirm: (amount) async {
          await viewModel.setMonthAmount(occurrence, amount);
          if (mounted) setState(() => _isEditingAmount = false);
        },
      );
    }

    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: () => setState(() => _isEditingAmount = true),
      title: const Text('Valor do mês'),
      subtitle: occurrence.hasCustomAmount
          ? Text('Regra: ${formatMoney(occurrence.expense.amount)}')
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            formatMoney(occurrence.amount),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 6),
          const Icon(Icons.edit_outlined, size: 18),
        ],
      ),
    );
  }

  Widget _paymentLine(
    BuildContext context,
    ExpensesViewModel viewModel,
    List<Wallet> wallets,
    ExpensePayment payment,
  ) {
    final theme = Theme.of(context);
    final wallet = _walletById(wallets, payment.walletId);
    final color = wallet?.color ?? theme.colorScheme.onSurfaceVariant;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: () => _editPayment(context, viewModel, wallets, payment),
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.16),
        child: Icon(
          wallet?.icon ?? Icons.payments_outlined,
          size: 20,
          color: color,
        ),
      ),
      title: Text(wallet?.name ?? 'Outro dinheiro'),
      subtitle: Text(DateFormat.yMMMd('pt_BR').format(payment.paidAt)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            formatMoney(payment.amount),
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          IconButton(
            onPressed: () {
              final occurrence = viewModel.occurrenceIn(
                widget.expenseId,
                widget.month,
              );
              if (occurrence != null &&
                  occurrence.offRule &&
                  occurrence.payments.length == 1) {
                Navigator.of(context).pop();
              }
              viewModel.removePayment(payment);
            },
            icon: const Icon(Icons.close, size: 18),
            tooltip: 'Remover pagamento',
          ),
        ],
      ),
    );
  }

  Future<void> _editPayment(
    BuildContext context,
    ExpensesViewModel viewModel,
    List<Wallet> wallets,
    ExpensePayment payment,
  ) async {
    final edit = await PaySheet.show(
      context,
      title: 'Editar pagamento',
      wallets: wallets,
      origin: payment.origin,
      paidAt: payment.paidAt,
      amount: payment.amount,
      latestCheckAtOf: (walletId) =>
          viewModel.snapshot.latestCheckOf(walletId)?.checkedAt,
      isEdit: true,
    );
    final occurrence = viewModel.occurrenceIn(widget.expenseId, widget.month);
    if (edit == null || occurrence == null) return;

    await viewModel.savePaymentLine(
      occurrence,
      id: payment.id,
      origin: edit.origin,
      amount: edit.amount,
      paidAt: edit.paidAt,
    );
  }

  Future<void> _payAnotherWay(
    BuildContext context,
    ExpensesViewModel viewModel,
    ExpenseOccurrence occurrence,
    List<Wallet> wallets,
  ) async {
    final edit = await PaySheet.show(
      context,
      title: 'Pagar ${occurrence.expense.name}',
      wallets: wallets,
      origin: viewModel.defaultOriginFor(occurrence),
      paidAt: occurrence.suggestedPaidAt(DateTime.now()),
      amount: occurrence.remaining,
      payable: occurrence,
      checkFor: (origin) =>
          viewModel.checkCoveringDue(occurrence, origin.walletId),
      latestCheckAtOf: (walletId) =>
          viewModel.snapshot.latestCheckOf(walletId)?.checkedAt,
    );
    if (edit == null) return;

    if (edit.closesMonth) {
      await viewModel.payClosingMonth(
        occurrence,
        origin: edit.origin,
        amount: edit.amount,
        paidAt: edit.paidAt,
      );
      return;
    }
    await viewModel.savePaymentLine(
      occurrence,
      origin: edit.origin,
      amount: edit.amount,
      paidAt: edit.paidAt,
    );
  }

  Future<void> _markPaid(
    BuildContext context,
    ExpensesViewModel viewModel,
    ExpenseOccurrence occurrence,
  ) async {
    final origin = viewModel.defaultOriginFor(occurrence);
    final paidAt = await choosePaidAt(
      context,
      viewModel: viewModel,
      payable: occurrence,
      walletId: origin.walletId,
    );
    if (paidAt == null) return;

    await viewModel.settle(occurrence, origin: origin, paidAt: paidAt);
  }

  Widget _footer(
    BuildContext context,
    ExpensesViewModel viewModel,
    ExpenseOccurrence occurrence,
    List<Wallet> wallets,
  ) {
    final theme = Theme.of(context);

    if (occurrence.isPaid) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${occurrence.offRule ? 'Fora da regra atual' : 'Quitada'} · '
            '${formatMoney(occurrence.paidAmount)} pagos',
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () {
              if (occurrence.offRule) Navigator.of(context).pop();
              viewModel.clearPayments(occurrence);
            },
            icon: const Icon(Icons.undo, size: 18),
            label: const Text('Desfazer pagamentos'),
          ),
        ],
      );
    }

    final wallet = _walletById(
      wallets,
      viewModel.defaultWalletIdFor(occurrence),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Falta ${formatMoney(occurrence.remaining)}',
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.error,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: () => _markPaid(context, viewModel, occurrence),
          child: const Text('Marcar como paga'),
        ),
        const SizedBox(height: 6),
        Text(
          wallet == null ? 'Outro dinheiro' : 'Sai de ${wallet.name}',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        TextButton(
          onPressed: () =>
              _payAnotherWay(context, viewModel, occurrence, wallets),
          child: const Text('Outro valor ou data'),
        ),
      ],
    );
  }

  Wallet? _walletById(List<Wallet> wallets, int? id) {
    if (id == null) return null;
    for (final wallet in wallets) {
      if (wallet.id == id) return wallet;
    }
    return null;
  }
}

enum _ExpenseMenuAction { edit, endHere, delete }

class _ExpenseMenu extends StatelessWidget {
  const _ExpenseMenu({required this.occurrence});

  final ExpenseOccurrence occurrence;

  @override
  Widget build(BuildContext context) {
    final errorColor = Theme.of(context).colorScheme.error;

    return PopupMenuButton<_ExpenseMenuAction>(
      tooltip: 'Mais opções',
      onSelected: (action) => _run(context, action),
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: _ExpenseMenuAction.edit,
          child: Text('Editar despesa'),
        ),
        if (occurrence.expense.canEndIn(occurrence.month))
          const PopupMenuItem(
            value: _ExpenseMenuAction.endHere,
            child: Text('Encerrar neste mês'),
          ),
        PopupMenuItem(
          value: _ExpenseMenuAction.delete,
          child: Text('Excluir despesa', style: TextStyle(color: errorColor)),
        ),
      ],
    );
  }

  Future<void> _run(BuildContext context, _ExpenseMenuAction action) async {
    final viewModel = context.read<ExpensesViewModel>();
    final navigator = Navigator.of(context);
    final expense = occurrence.expense;

    switch (action) {
      case _ExpenseMenuAction.edit:
        navigator.pop();
        await navigator.push(
          ExpenseFormPage.route(
            referenceMonth: viewModel.month,
            wallets: viewModel.snapshot.wallets,
            cards: viewModel.snapshot.cards,
            expense: expense,
            payments: viewModel.snapshot.paymentsOf(expense.id!),
          ),
        );
      case _ExpenseMenuAction.endHere:
        navigator.pop();
        await viewModel.endRecurringExpense(expense, viewModel.month);
      case _ExpenseMenuAction.delete:
        final choice = await _confirmDelete(context, viewModel, expense);
        if (choice == null) return;
        navigator.pop();
        if (choice == _DeleteChoice.endHere) {
          await viewModel.endRecurringExpense(expense, viewModel.month);
          return;
        }
        await viewModel.deleteExpense(expense);
    }
  }
}

enum _DeleteChoice { endHere, deleteAll }

Future<_DeleteChoice?> _confirmDelete(
  BuildContext context,
  ExpensesViewModel viewModel,
  Expense expense,
) {
  final paymentCount = viewModel.snapshot.paymentsOf(expense.id!).length;
  final paidTotal = formatMoney(viewModel.snapshot.totalPaidOf(expense.id!));

  return showDialog<_DeleteChoice>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Excluir ${expense.name}?'),
      content: Text(
        paymentCount == 0
            ? 'Ela sai de todos os meses.'
            : paymentCount == 1
            ? 'Excluir apaga também 1 pagamento ($paidTotal) do histórico.'
            : 'Excluir apaga também $paymentCount pagamentos ($paidTotal) '
                  'do histórico.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        if (paymentCount > 0 && expense.canEndIn(viewModel.month))
          TextButton(
            onPressed: () => Navigator.pop(context, _DeleteChoice.endHere),
            child: const Text('Encerrar neste mês'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context, _DeleteChoice.deleteAll),
          child: Text(paymentCount == 0 ? 'Excluir' : 'Excluir tudo'),
        ),
      ],
    ),
  );
}

class _AmountEditor extends StatefulWidget {
  const _AmountEditor({
    super.key,
    required this.initialAmount,
    required this.canReset,
    required this.onReset,
    required this.onCancel,
    required this.onConfirm,
  });

  final double initialAmount;
  final bool canReset;
  final VoidCallback onReset;
  final VoidCallback onCancel;
  final ValueChanged<double> onConfirm;

  @override
  State<_AmountEditor> createState() => _AmountEditorState();
}

class _AmountEditorState extends State<_AmountEditor> {
  late double _amount = widget.initialAmount;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MoneyField(
          initialValue: _amount,
          label: 'Valor do mês',
          autofocus: true,
          onChanged: (value) => setState(() => _amount = value),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            TextButton(
              onPressed: widget.onCancel,
              child: const Text('Cancelar'),
            ),
            if (widget.canReset)
              TextButton(
                onPressed: widget.onReset,
                child: const Text('Valor da regra'),
              ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton(
                onPressed: () => widget.onConfirm(_amount),
                child: const Text('Salvar'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
