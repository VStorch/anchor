import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/widgets/money_field.dart';
import '../../../wallets/models/payout_schedule.dart';
import '../../models/onboarding_draft.dart';
import '../../viewmodels/onboarding_view_model.dart';
import 'onboarding_widgets.dart';

class IncomeStep extends StatelessWidget {
  const IncomeStep({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<OnboardingViewModel>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const StepHeader(
          title: 'Quanto você recebe?',
          message:
              'O valor que cai na sua conta todo mês, já com os descontos.',
        ),
        IncomeForm(
          key: const ValueKey('income-salary'),
          income: viewModel.salary,
          amountLabel: 'Salário',
        ),
        const SizedBox(height: 28),
        YesNoQuestion(
          question: 'Recebe VR, VA ou vale mercado?',
          value: viewModel.hasBenefit,
          onChanged: viewModel.setHasBenefit,
        ),
        if (viewModel.hasBenefit == true) ...[
          const SizedBox(height: 20),
          TextFormField(
            initialValue: viewModel.benefit.name,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Nome do benefício',
              hintText: 'VR, VA, mercado...',
            ),
            onChanged: (value) =>
                viewModel.edit(() => viewModel.benefit.name = value),
          ),
          const SizedBox(height: 16),
          IncomeForm(
            key: const ValueKey('income-benefit'),
            income: viewModel.benefit,
            amountLabel: 'Valor do benefício',
          ),
        ],
      ],
    );
  }
}

/// Amount, schedule and day of one monthly pay, with the date it lands on
/// this month.
class IncomeForm extends StatelessWidget {
  const IncomeForm({
    super.key,
    required this.income,
    required this.amountLabel,
  });

  final IncomeDraft income;
  final String amountLabel;

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<OnboardingViewModel>();
    final theme = Theme.of(context);
    final schedule = income.schedule;
    final date = income.dateIn(viewModel.month);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MoneyField(
          initialValue: income.amount,
          label: amountLabel,
          onChanged: (value) => viewModel.edit(() => income.amount = value),
        ),
        const SizedBox(height: 16),
        SegmentedButton<bool>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: false, label: Text('Dia fixo')),
            ButtonSegment(value: true, label: Text('Nº dia útil')),
          ],
          selected: {schedule.isBusinessDay},
          onSelectionChanged: (selection) => viewModel.edit(
            () => income.setSchedule(
              selection.single
                  ? PayoutSchedule.businessDay
                  : PayoutSchedule.dayOfMonth,
            ),
          ),
        ),
        if (schedule.isBusinessDay)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Sábado conta como dia útil'),
            value: schedule == PayoutSchedule.businessDaySaturday,
            onChanged: (countSaturday) => viewModel.edit(
              () => income.setSchedule(
                countSaturday
                    ? PayoutSchedule.businessDaySaturday
                    : PayoutSchedule.businessDay,
              ),
            ),
          ),
        const SizedBox(height: 12),
        DayButton(
          label: schedule.isBusinessDay
              ? 'Cai no ${income.day}º dia útil'
              : 'Cai no dia ${income.day}',
          placeholder: schedule.isBusinessDay
              ? 'Qual dia útil'
              : 'Dia em que cai',
          sheetTitle: schedule.isBusinessDay
              ? 'Em qual dia útil cai?'
              : 'Em que dia cai?',
          day: income.day,
          dayCount: income.dayCount,
          onPicked: (day) => viewModel.edit(() => income.day = day),
        ),
        if (date != null) ...[
          const SizedBox(height: 8),
          Text(
            'Em ${monthName(date)} cai ${weekdayAndDay(date)}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}
