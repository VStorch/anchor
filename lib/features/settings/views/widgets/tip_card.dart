import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/app_tip.dart';
import '../../viewmodels/settings_view_model.dart';

/// The tab's tip until "Entendi" is tapped; nothing afterwards.
class TipCard extends StatelessWidget {
  const TipCard({super.key, required this.tip});

  final AppTip tip;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsViewModel>();
    if (!settings.showsTip(tip)) return const SizedBox.shrink();

    final theme = Theme.of(context);
    return Card(
      key: ValueKey('tip-${tip.id}'),
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
        child: Row(
          children: [
            Icon(
              Icons.lightbulb_outline,
              size: 20,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(tip.message, style: theme.textTheme.bodyMedium),
            ),
            TextButton(
              onPressed: () => settings.dismissTip(tip),
              child: const Text('Entendi'),
            ),
          ],
        ),
      ),
    );
  }
}
