import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../core/utils/money.dart';
import '../../../../core/widgets/money_field.dart';
import '../../../wallets/models/wallet.dart';
import '../../models/expense_occurrence.dart';
import '../../models/expense_payment.dart';
import '../../models/expense_type.dart';
import '../../viewmodels/expenses_view_model.dart';
import '../expense_form_page.dart';

class ExpenseLedgerSheet extends StatefulWidget {
  const ExpenseLedgerSheet({super.key, required this.expenseId});

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
        child: ExpenseLedgerSheet(expenseId: occurrence.expense.id!),
      ),
    );
  }

  final int expenseId;

  @override
  State<ExpenseLedgerSheet> createState() => _ExpenseLedgerSheetState();
}

class _ExpenseLedgerSheetState extends State<ExpenseLedgerSheet> {
  bool _isEditingAmount = false;
  int? _editingPaymentId;
  bool _isAddingPayment = false;

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<ExpensesViewModel>();
    final occurrence = viewModel.occurrenceOf(widget.expenseId);
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
              'Vence em ${DateFormat.yMMMMd('pt_BR').format(occurrence.dueDate)}'
              '${occurrence.installmentLabel != null ? ' · parcela ${occurrence.installmentLabel}' : ''}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            _monthAmount(context, viewModel, occurrence),
            const SizedBox(height: 20),
            Text(
              'Pagamentos',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            if (occurrence.payments.isEmpty && !_isAddingPayment)
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
            if (_isAddingPayment)
              _PaymentEditor(
                key: const ValueKey('new-payment'),
                wallets: wallets,
                initialWalletId: viewModel.defaultWalletIdFor(occurrence),
                initialAmount: occurrence.remaining,
                onCancel: () => setState(() => _isAddingPayment = false),
                onConfirm: (walletId, amount) async {
                  await viewModel.savePaymentLine(
                    occurrence,
                    walletId: walletId,
                    amount: amount,
                  );
                  if (mounted) setState(() => _isAddingPayment = false);
                },
              )
            else
              TextButton.icon(
                onPressed: () => setState(() {
                  _isAddingPayment = true;
                  _editingPaymentId = null;
                }),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Adicionar pagamento'),
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
    if (_editingPaymentId == payment.id) {
      return _PaymentEditor(
        key: ValueKey('payment-${payment.id}'),
        wallets: wallets,
        initialWalletId: payment.walletId,
        initialAmount: payment.amount,
        onCancel: () => setState(() => _editingPaymentId = null),
        onConfirm: (walletId, amount) async {
          final occurrence = viewModel.occurrenceOf(widget.expenseId);
          if (occurrence == null) return;
          await viewModel.savePaymentLine(
            occurrence,
            id: payment.id,
            walletId: walletId,
            amount: amount,
          );
          if (mounted) setState(() => _editingPaymentId = null);
        },
      );
    }

    final theme = Theme.of(context);
    final wallet = _walletById(wallets, payment.walletId);

    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: () => setState(() {
        _editingPaymentId = payment.id;
        _isAddingPayment = false;
      }),
      leading: CircleAvatar(
        backgroundColor: (wallet?.color ?? theme.colorScheme.primary)
            .withValues(alpha: 0.16),
        child: Icon(
          wallet?.icon ?? Icons.payments_outlined,
          size: 20,
          color: wallet?.color ?? theme.colorScheme.primary,
        ),
      ),
      title: Text(wallet?.name ?? 'Sem carteira'),
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
            onPressed: () => viewModel.removePayment(payment),
            icon: const Icon(Icons.close, size: 18),
            tooltip: 'Remover pagamento',
          ),
        ],
      ),
    );
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
            'Quitada · ${formatMoney(occurrence.paidAmount)} pagos',
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => viewModel.clearPayments(occurrence),
            icon: const Icon(Icons.undo, size: 18),
            label: const Text('Desfazer pagamentos'),
          ),
        ],
      );
    }

    final walletId = viewModel.defaultWalletIdFor(occurrence);
    final wallet = _walletById(wallets, walletId);

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
          onPressed: () => viewModel.settle(occurrence, walletId: walletId),
          child: Text(wallet == null ? 'Quitar' : 'Quitar com ${wallet.name}'),
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
        if (occurrence.expense.type == ExpenseType.recurring)
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
            expense: expense,
          ),
        );
      case _ExpenseMenuAction.endHere:
        navigator.pop();
        await viewModel.endRecurringExpense(expense, viewModel.month);
      case _ExpenseMenuAction.delete:
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Excluir ${expense.name}?'),
            content: const Text('Os pagamentos dela saem de todos os meses.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Excluir'),
              ),
            ],
          ),
        );
        if (confirmed != true) return;
        navigator.pop();
        await viewModel.deleteExpense(expense);
    }
  }
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

class _PaymentEditor extends StatefulWidget {
  const _PaymentEditor({
    super.key,
    required this.wallets,
    required this.initialWalletId,
    required this.initialAmount,
    required this.onCancel,
    required this.onConfirm,
  });

  final List<Wallet> wallets;
  final int? initialWalletId;
  final double initialAmount;
  final VoidCallback onCancel;
  final Future<void> Function(int? walletId, double amount) onConfirm;

  @override
  State<_PaymentEditor> createState() => _PaymentEditorState();
}

class _PaymentEditorState extends State<_PaymentEditor> {
  late int? _walletId = widget.initialWalletId;
  late double _amount = widget.initialAmount;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: widget.wallets
                  .map(
                    (wallet) => ChoiceChip(
                      label: Text(wallet.name),
                      selected: _walletId == wallet.id,
                      onSelected: (_) => setState(() => _walletId = wallet.id),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 12),
            MoneyField(
              initialValue: _amount,
              label: 'Valor pago',
              onChanged: (value) => setState(() => _amount = value),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton(
                  onPressed: widget.onCancel,
                  child: const Text('Cancelar'),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: _amount > 0
                        ? () => widget.onConfirm(_walletId, _amount)
                        : null,
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
}
