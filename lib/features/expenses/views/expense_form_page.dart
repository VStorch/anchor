import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/utils/money.dart';
import '../../../core/utils/month.dart';
import '../../../core/widgets/day_of_month_picker.dart';
import '../../../core/widgets/money_field.dart';
import '../../../core/widgets/month_picker_sheet.dart';
import '../../../core/widgets/movement_date_picker.dart';
import '../../../core/widgets/section_header.dart';
import '../../cards/models/credit_card.dart';
import '../../wallets/models/wallet.dart';
import '../../wallets/models/wallet_kind.dart';
import '../models/expense.dart';
import '../models/expense_payment.dart';
import '../models/expense_type.dart';
import '../repositories/expense_repository.dart';
import '../viewmodels/expense_form_view_model.dart';

class ExpenseFormPage extends StatelessWidget {
  const ExpenseFormPage({
    super.key,
    required this.referenceMonth,
    required this.wallets,
    this.cards = const <CreditCard>[],
    this.expense,
    this.card,
    this.payments = const <ExpensePayment>[],
    this.invoiceMonth,
  });

  static Future<void> open(
    BuildContext context, {
    required Month referenceMonth,
    required List<Wallet> wallets,
    List<CreditCard> cards = const <CreditCard>[],
    Expense? expense,
    CreditCard? card,
    List<ExpensePayment> payments = const <ExpensePayment>[],
  }) => Navigator.of(context).push(
    route(
      referenceMonth: referenceMonth,
      wallets: wallets,
      cards: cards,
      expense: expense,
      card: card,
      payments: payments,
    ),
  );

  static MaterialPageRoute<void> route({
    required Month referenceMonth,
    required List<Wallet> wallets,
    List<CreditCard> cards = const <CreditCard>[],
    Expense? expense,
    CreditCard? card,
    List<ExpensePayment> payments = const <ExpensePayment>[],
    Month? invoiceMonth,
  }) => MaterialPageRoute<void>(
    builder: (_) => ExpenseFormPage(
      referenceMonth: referenceMonth,
      wallets: wallets,
      cards: cards,
      expense: expense,
      card: card,
      payments: payments,
      invoiceMonth: invoiceMonth,
    ),
  );

  final Month referenceMonth;
  final List<Wallet> wallets;
  final List<CreditCard> cards;
  final Expense? expense;
  final CreditCard? card;
  final List<ExpensePayment> payments;
  final Month? invoiceMonth;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => ExpenseFormViewModel(
        repository: context.read<ExpenseRepository>(),
        referenceMonth: referenceMonth,
        expense: expense,
        likelyWalletId: _likelyWalletId(),
        cards: cards,
        card: card,
        payments: payments,
        invoiceMonth: invoiceMonth,
      ),
      child: _ExpenseFormView(wallets: wallets, cards: cards),
    );
  }

  int? _likelyWalletId() {
    for (final wallet in wallets) {
      if (wallet.kind == WalletKind.salary) return wallet.id;
    }
    return wallets.isEmpty ? null : wallets.first.id;
  }
}

class _ExpenseFormView extends StatelessWidget {
  const _ExpenseFormView({required this.wallets, required this.cards});

  final List<Wallet> wallets;
  final List<CreditCard> cards;

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<ExpenseFormViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          viewModel.isEditing
              ? 'Editar despesa'
              : viewModel.isNewPurchase
              ? 'Nova compra no ${viewModel.card!.name}'
              : 'Nova despesa',
        ),
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
          if (cards.isNotEmpty) ...[
            const SizedBox(height: 16),
            _SourceDropdown(
              viewModel: viewModel,
              wallets: wallets,
              cards: cards,
            ),
          ],
          const SizedBox(height: 16),
          _TypeDropdown(viewModel: viewModel),
          const SizedBox(height: 16),
          MoneyField(
            initialValue: viewModel.amount,
            label: switch (viewModel.type) {
              ExpenseType.installment => 'Valor da parcela',
              ExpenseType.recurring => 'Valor mensal',
              ExpenseType.single => 'Valor',
            },
            onChanged: viewModel.setAmount,
          ),
          if (viewModel.isInstallment) ...[
            const SizedBox(height: 24),
            const SectionHeader(title: 'Parcelamento'),
            TextFormField(
              initialValue: viewModel.totalInstallments?.toString() ?? '',
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(3),
              ],
              decoration: InputDecoration(
                labelText: 'Total de parcelas',
                hintText: 'Em quantas vezes',
                errorText: viewModel.totalInstallmentsError,
              ),
              onChanged: (text) =>
                  viewModel.setTotalInstallments(int.tryParse(text)),
            ),
            const SizedBox(height: 12),
            if (!viewModel.showsInstallmentPlan)
              Text(
                'Com o total, aparecem as parcelas já pagas e quanto falta.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              )
            else
              _InstallmentStepper(
                label: 'Parcelas já pagas',
                value: viewModel.settledInstallments,
                onChanged: viewModel.setSettledInstallments,
              ),
            if (viewModel.installmentPreview != null) ...[
              const SizedBox(height: 12),
              Text(
                viewModel.installmentPreview!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
          const SizedBox(height: 24),
          if (cards.isEmpty) ...[
            _SourceDropdown(
              viewModel: viewModel,
              wallets: wallets,
              cards: cards,
            ),
            const SizedBox(height: 24),
          ],
          if (viewModel.card != null) ...[
            const SectionHeader(title: 'Compra'),
            _PurchaseDateField(viewModel: viewModel),
            if (viewModel.purchasedAt == null) ...[
              const SizedBox(height: 12),
              _MonthField(viewModel: viewModel),
            ],
            const SizedBox(height: 12),
            _InvoiceLine(viewModel: viewModel),
          ] else ...[
            SectionHeader(title: _startMonthTitle(viewModel.type)),
            _MonthField(viewModel: viewModel),
          ],
          if (viewModel.type == ExpenseType.recurring) ...[
            const SizedBox(height: 12),
            _EndMonthField(viewModel: viewModel),
          ],
          if (viewModel.card == null) ...[
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
          ],
          if (viewModel.showsInstallmentPlan) ...[
            const SizedBox(height: 28),
            _TotalPreview(viewModel: viewModel),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: viewModel.isValid && !viewModel.isSaving
                ? () => _save(context, viewModel)
                : null,
            child: Text(
              viewModel.totalInstallmentsError != null
                  ? 'Total de parcelas: '
                        '${viewModel.totalInstallmentsError!.toLowerCase()}'
                  : viewModel.needsDueDay
                  ? 'Escolha o dia do vencimento'
                  : viewModel.needsInstallmentCount
                  ? 'Informe o total de parcelas'
                  : viewModel.leavesOpenedInvoice
                  ? 'Adicionar à fatura de ${_monthName(viewModel.invoiceMonth!)}'
                  : viewModel.isEditing
                  ? 'Salvar alterações'
                  : viewModel.isNewPurchase
                  ? 'Salvar compra'
                  : 'Cadastrar despesa',
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _save(BuildContext context, ExpenseFormViewModel viewModel) async {
  final leftOut = viewModel.monthsLeftOffRule.length;
  if (leftOut > 0) {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mudar a regra?'),
        content: Text(
          leftOut == 1
              ? '1 mês já pago fica fora da nova regra e continua no histórico.'
              : '$leftOut meses já pagos ficam fora da nova regra e continuam '
                    'no histórico.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Voltar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
  }

  await viewModel.save();
  if (context.mounted) Navigator.of(context).pop();
}

String _startMonthTitle(ExpenseType type) => switch (type) {
  ExpenseType.recurring => 'Começa em',
  ExpenseType.installment => 'Próxima parcela',
  ExpenseType.single => 'Vence em',
};

String _monthName(Month month) =>
    DateFormat.MMMM('pt_BR').format(month.firstDay);

class _PurchaseDateField extends StatelessWidget {
  const _PurchaseDateField({required this.viewModel});

  final ExpenseFormViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final purchasedAt = viewModel.purchasedAt;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      tileColor: Theme.of(
        context,
      ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      leading: const Icon(Icons.shopping_bag_outlined),
      title: const Text('Data da compra'),
      subtitle: Text(
        purchasedAt == null
            ? 'Não informada'
            : DateFormat.yMMMMd('pt_BR').format(purchasedAt),
      ),
      trailing: const Icon(Icons.edit_calendar_outlined),
      onTap: () async {
        final day = await pickMovementDate(
          context,
          purchasedAt ?? viewModel.startMonth.suggestedDate,
        );
        if (day != null) viewModel.setPurchasedAt(day);
      },
    );
  }
}

class _InvoiceLine extends StatelessWidget {
  const _InvoiceLine({required this.viewModel});

  final ExpenseFormViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final purchasedAt = viewModel.purchasedAt;
    final invoice = _monthName(viewModel.invoiceMonth ?? viewModel.startMonth);
    final leaves = viewModel.leavesOpenedInvoice && purchasedAt != null;
    final foreground = leaves
        ? theme.colorScheme.onTertiaryContainer
        : theme.colorScheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: leaves
            ? theme.colorScheme.tertiaryContainer
            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(
            leaves ? Icons.info_outline : CreditCard.icon,
            size: 20,
            color: foreground,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Fatura de $invoice',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: foreground,
                  ),
                ),
                if (leaves)
                  Text(
                    'Compra de ${DateFormat('dd/MM', 'pt_BR').format(purchasedAt)} '
                    'vai para a fatura de $invoice',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: foreground,
                    ),
                  ),
                if (viewModel.isInstallment &&
                    viewModel.settledInstallments > 0)
                  Text(
                    'Próxima parcela em ${viewModel.startMonth.label}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: foreground,
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
          title: _startMonthTitle(viewModel.type),
        );
        if (month != null) viewModel.setStartMonth(month);
      },
    );
  }
}

class _EndMonthField extends StatelessWidget {
  const _EndMonthField({required this.viewModel});

  final ExpenseFormViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final endMonth = viewModel.endMonth;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          contentPadding: const EdgeInsets.only(left: 16, right: 4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          tileColor: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.4,
          ),
          leading: const Icon(Icons.event_busy_outlined),
          title: const Text('Termina em'),
          subtitle: Text(endMonth?.label ?? 'Sem fim'),
          trailing: endMonth == null
              ? const Padding(
                  padding: EdgeInsets.only(right: 12),
                  child: Icon(Icons.edit_calendar_outlined),
                )
              : IconButton(
                  onPressed: () => viewModel.setEndMonth(null),
                  icon: const Icon(Icons.close),
                  tooltip: 'Sem fim',
                ),
          onTap: () async {
            final month = await MonthPickerSheet.show(
              context,
              initialMonth: endMonth ?? viewModel.startMonth,
              title: 'Último mês da cobrança',
            );
            if (month != null) viewModel.setEndMonth(month);
          },
        ),
        if (viewModel.endsBeforeStart)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
            child: Text(
              'Termina antes de começar',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
      ],
    );
  }
}

class _SourceDropdown extends StatelessWidget {
  const _SourceDropdown({
    required this.viewModel,
    required this.wallets,
    required this.cards,
  });

  final ExpenseFormViewModel viewModel;
  final List<Wallet> wallets;
  final List<CreditCard> cards;

  @override
  Widget build(BuildContext context) {
    if (wallets.isEmpty && cards.isEmpty) return const SizedBox.shrink();

    return DropdownButtonFormField<PaymentSource>(
      value: viewModel.source,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Pago com'),
      items: [
        const DropdownMenuItem<PaymentSource>(
          value: (walletId: null, cardId: null),
          child: Text('Definir na hora'),
        ),
        ...wallets.map(
          (wallet) => _item(
            (walletId: wallet.id, cardId: null),
            wallet.icon,
            wallet.color,
            wallet.name,
          ),
        ),
        ...cards.map(
          (card) => _item(
            (walletId: null, cardId: card.id),
            CreditCard.icon,
            Theme.of(context).colorScheme.primary,
            card.name,
          ),
        ),
      ],
      onChanged: (source) {
        if (source != null) viewModel.setSource(source);
      },
    );
  }

  DropdownMenuItem<PaymentSource> _item(
    PaymentSource value,
    IconData icon,
    Color color,
    String label,
  ) => DropdownMenuItem<PaymentSource>(
    value: value,
    child: Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
      ],
    ),
  );
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
                if (viewModel.installmentPlan != null)
                  Text(
                    viewModel.installmentPlan!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                if (viewModel.card != null)
                  Text(
                    'Na fatura de '
                    '${_monthName(viewModel.invoiceMonth ?? viewModel.startMonth)}',
                    style: theme.textTheme.bodySmall?.copyWith(
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
