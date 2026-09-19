import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/anchor_logo.dart';
import '../viewmodels/onboarding_view_model.dart';
import 'widgets/balance_step.dart';
import 'widgets/bills_step.dart';
import 'widgets/card_step.dart';
import 'widgets/income_step.dart';
import 'widgets/installments_step.dart';
import 'widgets/onboarding_widgets.dart';
import 'widgets/reminders_step.dart';

class OnboardingPage extends StatelessWidget {
  const OnboardingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<OnboardingViewModel>();
    final step = viewModel.step;

    return PopScope(
      canPop: viewModel.isFirstStep,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) viewModel.back();
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              _TopBar(
                viewModel: viewModel,
                onSkipSetup: () => _skipSetup(context, viewModel),
              ),
              LinearProgressIndicator(value: viewModel.progress),
              Expanded(
                child: SingleChildScrollView(
                  key: ValueKey(step),
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                  child: switch (step) {
                    OnboardingStep.welcome => const _WelcomeStep(),
                    OnboardingStep.income => const IncomeStep(),
                    OnboardingStep.balance => const BalanceStep(),
                    OnboardingStep.bills => const BillsStep(),
                    OnboardingStep.installments => const InstallmentsStep(),
                    OnboardingStep.card => const CardStep(),
                    OnboardingStep.reminders => const RemindersStep(),
                  },
                ),
              ),
              _BottomBar(viewModel: viewModel),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _skipSetup(
    BuildContext context,
    OnboardingViewModel viewModel,
  ) async {
    if (viewModel.hasAnswers) {
      final leave = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Sair da configuração?'),
          content: const Text(
            'O que você preencheu não será salvo. Dá para cadastrar tudo '
            'depois pelas abas do app.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Continuar configurando'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Sair'),
            ),
          ],
        ),
      );
      if (leave != true) return;
    }
    await viewModel.skipSetup();
  }
}

/// Back and "Pular configuração" in a row that grows with the font, where an
/// app bar would clip the button at a large text size.
class _TopBar extends StatelessWidget {
  const _TopBar({required this.viewModel, required this.onSkipSetup});

  final OnboardingViewModel viewModel;
  final VoidCallback onSkipSetup;

  @override
  Widget build(BuildContext context) {
    final isSaving = viewModel.isSaving;

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
      child: Row(
        children: [
          if (viewModel.isFirstStep)
            const SizedBox(width: 48, height: 48)
          else
            IconButton(
              tooltip: 'Voltar',
              onPressed: isSaving ? null : viewModel.back,
              icon: const Icon(Icons.arrow_back),
            ),
          const SizedBox(width: 8),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: isSaving ? null : onSkipSetup,
                child: const Text(
                  'Pular configuração',
                  textAlign: TextAlign.end,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.viewModel});

  final OnboardingViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final step = viewModel.step;
    final isSaving = viewModel.isSaving;

    final (String? secondary, VoidCallback? onSecondary) = switch (step) {
      OnboardingStep.welcome => (null, null),
      OnboardingStep.reminders => (
        'Agora não',
        isSaving ? null : () => viewModel.finish(withReminders: false),
      ),
      _ => ('Pular', viewModel.skipStep),
    };
    final (String primary, VoidCallback? onPrimary) = switch (step) {
      OnboardingStep.welcome => ('Começar', viewModel.next),
      OnboardingStep.reminders => (
        'Ativar lembretes',
        isSaving ? null : () => viewModel.finish(withReminders: true),
      ),
      _ => (
        viewModel.blocker ?? 'Continuar',
        viewModel.canContinue ? viewModel.next : null,
      ),
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Row(
        children: [
          if (secondary != null) ...[
            TextButton(onPressed: onSecondary, child: Text(secondary)),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: FilledButton(
              onPressed: onPrimary,
              child: Text(primary, textAlign: TextAlign.center),
            ),
          ),
        ],
      ),
    );
  }
}

class _WelcomeStep extends StatelessWidget {
  const _WelcomeStep();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnchorLogo(size: 64),
        SizedBox(height: 24),
        StepHeader(
          title: 'Boas-vindas ao Anchor',
          message:
              'Salário, saldo e contas em poucos passos. Pule o que quiser.',
        ),
      ],
    );
  }
}
