import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/utils/money.dart';
import '../../../core/utils/month.dart';
import '../../../core/widgets/day_of_month_picker.dart';
import '../../../core/widgets/money_field.dart';
import '../../../core/widgets/month_picker_sheet.dart';
import '../../../core/widgets/section_header.dart';
import '../../wallets/models/wallet.dart';
import '../models/expense.dart';
import '../models/expense_type.dart';
import '../repositories/expense_repository.dart';
import '../viewmodels/expense_form_view_model.dart';

class ExpenseFormPage extends StatelessWidget {
  const ExpenseFormPage({
    super.key,
    required this.referenceMonth,
    required this.wallets,
    this.expense,
  });

  static Future<void> open(
    BuildContext context, {
    required Month referenceMonth,
    required List<Wallet> wallets,
    Expense? expense,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ExpenseFormPage(
          referenceMonth: referenceMonth,
          wallets: wallets,
          expense: expense,
        ),
      ),
    );
  }

  final Month referenceMonth;
  final List<Wallet> wallets;
  final Expense? expense;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => ExpenseFormViewModel(
        repository: context.read<ExpenseRepository>(),
        referenceMonth: referenceMonth,
        expense: expense,
      ),
      child: _ExpenseFormView(wallets: wallets),
    );
  }
}

class _ExpenseFormView extends StatelessWidget {
  const _ExpenseFormView({required this.wallets});

  final List<Wallet> wallets;

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<ExpenseFormViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: Text(viewModel.isEditing ? 'Editar despesa' : 'Nova despesa'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          TextFormField(
            initialValue: viewModel.name,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Nome da despesa',
              hintText: 'Plano de saúde, geladeira, mercado...',
            ),
            onChanged: viewModel.setName,
          ),
          const SizedBox(height: 16),
          _TypeDropdown(viewModel: viewModel),
          const SizedBox(height: 16),
          MoneyField(
            initialValue: viewModel.amount,
            label: viewModel.isInstallment
                ? 'Valor da parcela'
                : 'Valor mensal',
            onChanged: viewModel.setAmount,
          ),
          if (viewModel.isInstallment) ...[
            const SizedBox(height: 24),
            const SectionHeader(
              title: 'Parcelamento',
              subtitle: 'Informe quantas parcelas você já quitou',
            ),
            _InstallmentStepper(
              label: 'Total de parcelas',
              value: viewModel.totalInstallments,
              onChanged: viewModel.setTotalInstallments,
            ),
            const SizedBox(height: 12),
            _InstallmentStepper(
              label: 'Parcelas já pagas',
              value: viewModel.settledInstallments,
              onChanged: viewModel.setSettledInstallments,
            ),
          ],
          const SizedBox(height: 24),
          SectionHeader(
            title: viewModel.isInstallment
                ? 'Próxima parcela'
                : 'Primeira cobrança',
            subtitle: viewModel.typeHint,
          ),
          _MonthField(viewModel: viewModel),
          const SizedBox(height: 20),
          Text(
            'Dia do vencimento',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          DayOfMonthPicker(
            selectedDay: viewModel.dueDay,
            onDaySelected: viewModel.setDueDay,
          ),
          const SizedBox(height: 24),
          const SectionHeader(
            title: 'Como você costuma pagar',
            subtitle: 'Sugestão usada ao confirmar o pagamento',
          ),
          _WalletDropdown(viewModel: viewModel, wallets: wallets),
          const SizedBox(height: 28),
          _TotalPreview(viewModel: viewModel),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: viewModel.isValid && !viewModel.isSaving
                ? () async {
                    await viewModel.save();
                    if (context.mounted) Navigator.of(context).pop();
                  }
                : null,
            child: Text(
              viewModel.isEditing ? 'Salvar alterações' : 'Cadastrar despesa',
            ),
          ),
        ],
      ),
    );
  }
}

class _TypeDropdown extends StatelessWidget {
  const _TypeDropdown({required this.viewModel});

  final ExpenseFormViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<ExpenseType>(
      value: viewModel.type,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Tipo da despesa'),
      selectedItemBuilder: (context) => ExpenseType.values
          .map(
            (type) =>
                Align(alignment: Alignment.centerLeft, child: Text(type.label)),
          )
          .toList(),
      items: ExpenseType.values
          .map(
            (type) => DropdownMenuItem(
              value: type,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(type.label),
                  Text(
                    type.description,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
      onChanged: (type) {
        if (type != null) viewModel.setType(type);
      },
    );
  }
}

class _InstallmentStepper extends StatelessWidget {
  const _InstallmentStepper({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 6, 6, 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
          IconButton(
            onPressed: () => onChanged(value - 1),
            icon: const Icon(Icons.remove_circle_outline),
          ),
          SizedBox(
            width: 36,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            onPressed: () => onChanged(value + 1),
            icon: const Icon(Icons.add_circle_outline),
          ),
        ],
      ),
    );
  }
}

class _MonthField extends StatelessWidget {
  const _MonthField({required this.viewModel});

  final ExpenseFormViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      tileColor: Theme.of(
        context,
      ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      leading: const Icon(Icons.calendar_month_outlined),
      title: Text(viewModel.startMonth.label),
      trailing: const Icon(Icons.edit_calendar_outlined),
      onTap: () async {
        final month = await MonthPickerSheet.show(
          context,
          initialMonth: viewModel.startMonth,
          title: 'Mês da primeira cobrança',
        );
        if (month != null) viewModel.setStartMonth(month);
      },
    );
  }
}

class _WalletDropdown extends StatelessWidget {
  const _WalletDropdown({required this.viewModel, required this.wallets});

  final ExpenseFormViewModel viewModel;
  final List<Wallet> wallets;

  @override
  Widget build(BuildContext context) {
    if (wallets.isEmpty) {
      return Text(
        'Nenhuma carteira cadastrada ainda.',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      );
    }

    return DropdownButtonFormField<int?>(
      value: viewModel.walletId,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Fonte do pagamento'),
      items: [
        const DropdownMenuItem<int?>(
          value: null,
          child: Text('Definir na hora'),
        ),
        ...wallets.map(
          (wallet) => DropdownMenuItem<int?>(
            value: wallet.id,
            child: Row(
              children: [
                Icon(wallet.icon, size: 18, color: wallet.color),
                const SizedBox(width: 8),
                Text(wallet.name),
              ],
            ),
          ),
        ),
      ],
      onChanged: viewModel.setWalletId,
    );
  }
}

class _TotalPreview extends StatelessWidget {
  const _TotalPreview({required this.viewModel});

  final ExpenseFormViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(
            viewModel.type.icon,
            color: theme.colorScheme.onPrimaryContainer,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  viewModel.isInstallment
                      ? 'Ainda falta pagar'
                      : 'Impacto no mês',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                Text(
                  formatMoney(viewModel.totalCommitted),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
