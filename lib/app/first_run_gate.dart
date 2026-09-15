import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/utils/clock.dart';
import '../core/widgets/loading_view.dart';
import '../features/onboarding/services/onboarding_service.dart';
import '../features/onboarding/viewmodels/onboarding_view_model.dart';
import '../features/onboarding/views/onboarding_page.dart';
import '../features/reminders/viewmodels/reminders_view_model.dart';
import '../features/settings/viewmodels/settings_view_model.dart';
import 'app_shell.dart';

/// Shows the first-run setup to someone with nothing registered yet, and the
/// app to everyone else.
class FirstRunGate extends StatefulWidget {
  const FirstRunGate({super.key});

  @override
  State<FirstRunGate> createState() => _FirstRunGateState();
}

class _FirstRunGateState extends State<FirstRunGate> {
  Future<bool>? _needsOnboarding;

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsViewModel>();
    if (settings.onboardingDone) return;

    _needsOnboarding = context
        .read<OnboardingService>()
        .needsOnboarding(context.read<Clock>()())
        .then((needs) {
          if (!needs) settings.markOnboardingDone();
          return needs;
        });
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsViewModel>();
    if (settings.onboardingDone) return const AppShell();

    return FutureBuilder<bool>(
      future: _needsOnboarding,
      builder: (context, needs) => needs.data == true
          ? ChangeNotifierProvider(
              create: (context) => OnboardingViewModel(
                service: context.read<OnboardingService>(),
                settings: context.read<SettingsViewModel>(),
                reminders: context.read<RemindersViewModel>(),
                clock: context.read<Clock>(),
              ),
              child: const OnboardingPage(),
            )
          : const Scaffold(body: LoadingView()),
    );
  }
}
