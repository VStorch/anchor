import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../core/widgets/money_field.dart';
import '../../models/onboarding_draft.dart';
import '../../viewmodels/onboarding_view_model.dart';
import 'bills_step.dart';
import 'onboarding_widgets.dart';

class InstallmentsStep extends StatelessWidget {
  const InstallmentsStep({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<OnboardingViewModel>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const StepHeader(
          title: 'Compras parceladas',
          message:
              'Geladeira, celular, curso: o que ainda tem parcelas '
              'para pagar fora do cartão.',
        ),
        for (final installment in viewModel.installments)
          _InstallmentCard(key: ObjectKey(installment), item: installment),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
          ),
          onPressed: viewModel.addInstallment,
          icon: const Icon(Icons.add),
          label: const Text('Adicionar compra parcelada'),
        ),
      ],
    );
  }
}

class _InstallmentCard extends StatelessWidget {
  const _InstallmentCard({super.key, required this.item});

  final InstallmentDraft item;

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<OnboardingViewModel>();
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 8, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: item.name,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'O que foi comprado',
                    ),
                    onChanged: (value) =>
                        viewModel.edit(() => item.name = value),
                  ),
                ),
                IconButton(
                  tooltip: 'Remover compra',
                  onPressed: () => viewModel.removeInstallment(item),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 12),
                  MoneyField(
                    initialValue: item.amount,
                    label: 'Valor da parcela',
                    onChanged: (value) =>
                        viewModel.edit(() => item.amount = value),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Qual parcela vence este mês?',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _NumberField(
                          label: 'Parcela',
                          value: item.currentNumber,
                          onChanged: (value) =>
                              viewModel.edit(() => item.currentNumber = value),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text('de'),
                      ),
                      Expanded(
                        child: _NumberField(
                          label: 'Total',
                          value: item.total,
                          onChanged: (value) =>
                              viewModel.edit(() => item.total = value),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DayButton(
                    label: 'Vence dia ${item.dueDay}',
                    placeholder: 'Dia do vencimento',
                    sheetTitle: 'Em que dia vence?',
                    day: item.dueDay,
                    onPicked: (day) => viewModel.edit(() => item.dueDay = day),
                  ),
                  if (item.isPastDueBy(viewModel.today)) ...[
                    const SizedBox(height: 16),
                    PaidThisMonthQuestion(
                      paid: item.paidThisMonth,
                      onChanged: (value) =>
                          viewModel.edit(() => item.paidThisMonth = value),
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

class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int? value;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: value?.toString() ?? '',
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(3),
      ],
      decoration: InputDecoration(labelText: label),
      onChanged: (text) => onChanged(int.tryParse(text)),
    );
  }
}
