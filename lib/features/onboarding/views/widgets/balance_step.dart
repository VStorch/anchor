import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/widgets/money_field.dart';
import '../../../wallets/models/wallet_kind.dart';
import '../../models/onboarding_draft.dart';
import '../../viewmodels/onboarding_view_model.dart';
import 'onboarding_widgets.dart';

class BalanceStep extends StatelessWidget {
  const BalanceStep({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<OnboardingViewModel>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const StepHeader(title: 'Quanto tem hoje?'),
        for (final income in viewModel.incomes)
          Padding(
            key: ObjectKey(income),
            padding: const EdgeInsets.only(bottom: 24),
            child: _BalanceForm(income: income),
          ),
        if (viewModel.incomes
                .where((income) => income.kind == WalletKind.salary)
                .firstOrNull
            case final salary?)
          _ReserveQuestion(
            key: const ValueKey<String>('reserve'),
            salary: salary,
          ),
      ],
    );
  }
}

class _BalanceForm extends StatelessWidget {
  const _BalanceForm({required this.income});

  final IncomeDraft income;

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<OnboardingViewModel>();
    final today = viewModel.today;
    final date = income.dateIn(viewModel.month);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MoneyField(
          initialValue: income.balanceToday ?? 0,
          label: 'Tem em ${income.displayName}',
          allowNegative: true,
          onChanged: (value) =>
              viewModel.edit(() => income.balanceToday = value),
        ),
        if (date != null && income.isDueBy(today)) ...[
          const SizedBox(height: 16),
          YesNoQuestion(
            question:
                '${_payName(income)} de ${dayAndMonth(date)} já está nesse '
                'valor?',
            value: income.arrived,
            no: 'Ainda não caiu',
            onChanged: (value) => viewModel.edit(() => income.arrived = value),
          ),
        ],
      ],
    );
  }

  String _payName(IncomeDraft income) => income.kind == WalletKind.salary
      ? 'O salário'
      : 'O ${income.displayName}';
}

class _ReserveQuestion extends StatelessWidget {
  const _ReserveQuestion({super.key, required this.salary});

  final IncomeDraft salary;

  @override
  Widget build(BuildContext context) {
    final viewModel = context.read<OnboardingViewModel>();
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Reserva do dia a dia (opcional)',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        MoneyField(
          initialValue: salary.monthlyReserve ?? 0,
          label: 'Por mês',
          hint: 'Mercado, transporte, lanche',
          onChanged: (value) => viewModel.edit(
            () => salary.monthlyReserve = value > 0 ? value : null,
          ),
        ),
      ],
    );
  }
}
