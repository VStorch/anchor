import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../viewmodels/onboarding_view_model.dart';
import 'onboarding_widgets.dart';

class CardStep extends StatelessWidget {
  const CardStep({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<OnboardingViewModel>();
    final theme = Theme.of(context);
    final card = viewModel.card;
    final incomes = viewModel.incomes;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const StepHeader(
          title: 'Cartão de crédito',
          message:
              'As compras vão para a fatura, e ela vira uma conta do '
              'mês no dia do vencimento.',
        ),
        YesNoQuestion(
          question: 'Usa cartão de crédito?',
          value: viewModel.hasCard,
          onChanged: viewModel.setHasCard,
        ),
        if (viewModel.hasCard == true) ...[
          const SizedBox(height: 20),
          TextFormField(
            initialValue: card.name,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Nome do cartão',
              hintText: 'Nubank, Inter...',
            ),
            onChanged: (value) => viewModel.edit(() => card.name = value),
          ),
          const SizedBox(height: 16),
          DayButton(
            label: 'Fecha dia ${card.closingDay}',
            sheetTitle: 'Em que dia a fatura fecha?',
            day: card.closingDay,
            onPicked: (day) => viewModel.edit(() => card.closingDay = day),
          ),
          const SizedBox(height: 12),
          DayButton(
            label: 'Vence dia ${card.dueDay}',
            sheetTitle: 'Em que dia a fatura vence?',
            day: card.dueDay,
            onPicked: (day) => viewModel.edit(() => card.dueDay = day),
          ),
          if (incomes.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              'Paga a fatura com',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final income in incomes)
                  ChoiceChip(
                    label: Text(income.displayName),
                    selected: card.payer == income,
                    onSelected: (_) =>
                        viewModel.edit(() => card.payer = income),
                  ),
              ],
            ),
          ],
        ],
      ],
    );
  }
}
