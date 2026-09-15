import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../reminders/models/due_reminder.dart';
import '../../../reminders/models/reminder_lead.dart';
import '../../viewmodels/onboarding_view_model.dart';
import 'onboarding_widgets.dart';

class RemindersStep extends StatelessWidget {
  const RemindersStep({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<OnboardingViewModel>();
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StepHeader(
          title: 'Lembretes',
          message:
              'O Anchor avisa às ${DueReminder.hourOfDay}h quando uma conta '
              'está para vencer e ainda não foi paga.',
        ),
        Text(
          'Quando avisar?',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        SegmentedButton<ReminderLead>(
          showSelectedIcon: false,
          segments: [
            for (final lead in ReminderLead.values)
              ButtonSegment(value: lead, label: Text(lead.label)),
          ],
          selected: {viewModel.lead},
          onSelectionChanged: (selection) =>
              viewModel.setLead(selection.single),
        ),
        const SizedBox(height: 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.notifications_outlined,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Ao ativar, o Android pergunta se o Anchor pode mandar '
                'notificações. Dá para mudar depois em Ajustes.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
