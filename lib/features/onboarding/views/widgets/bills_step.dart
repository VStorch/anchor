import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/widgets/money_field.dart';
import '../../models/onboarding_draft.dart';
import '../../viewmodels/onboarding_view_model.dart';
import 'onboarding_widgets.dart';

class BillsStep extends StatelessWidget {
  const BillsStep({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<OnboardingViewModel>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const StepHeader(
          title: 'Contas de todo mês',
          message:
              'Toque nas que você tem. Cada uma pede o valor e o dia '
              'em que vence.',
        ),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final name in BillDraft.suggestions)
              FilterChip(
                label: Text(name),
                selected: viewModel.isSuggestionPicked(name),
                onSelected: (_) => viewModel.toggleSuggestion(name),
              ),
            ActionChip(
              avatar: const Icon(Icons.add),
              label: const Text('Outra'),
              onPressed: viewModel.addOtherBill,
            ),
          ],
        ),
        const SizedBox(height: 16),
        for (final bill in viewModel.bills)
          _BillCard(key: ObjectKey(bill), bill: bill),
      ],
    );
  }
}

class _BillCard extends StatelessWidget {
  const _BillCard({super.key, required this.bill});

  final BillDraft bill;

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<OnboardingViewModel>();
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: bill.isSuggestion
                      ? Text(
                          bill.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        )
                      : TextFormField(
                          initialValue: bill.name,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: const InputDecoration(
                            labelText: 'Nome da conta',
                          ),
                          onChanged: (value) =>
                              viewModel.edit(() => bill.name = value),
                        ),
                ),
                IconButton(
                  tooltip: 'Remover ${bill.name}',
                  onPressed: () => viewModel.removeBill(bill),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 8),
                  MoneyField(
                    initialValue: bill.amount,
                    onChanged: (value) =>
                        viewModel.edit(() => bill.amount = value),
                  ),
                  const SizedBox(height: 12),
                  DayButton(
                    label: 'Vence dia ${bill.dueDay}',
                    sheetTitle: 'Em que dia vence?',
                    day: bill.dueDay,
                    onPicked: (day) => viewModel.edit(() => bill.dueDay = day),
                  ),
                  if (bill.isPastDueBy(viewModel.today)) ...[
                    const SizedBox(height: 16),
                    PaidThisMonthQuestion(
                      paid: bill.paidThisMonth,
                      onChanged: (value) =>
                          viewModel.edit(() => bill.paidThisMonth = value),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Asked for a bill already past due this month; "Sim" is the likely answer.
class PaidThisMonthQuestion extends StatelessWidget {
  const PaidThisMonthQuestion({
    super.key,
    required this.paid,
    required this.onChanged,
  });

  final bool paid;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<OnboardingViewModel>();

    return YesNoQuestion(
      question: 'Já pagou a de ${monthName(viewModel.today)}?',
      value: paid,
      onChanged: onChanged,
    );
  }
}
