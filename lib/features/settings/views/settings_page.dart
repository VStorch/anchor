import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/section_header.dart';
import '../viewmodels/settings_view_model.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsViewModel>();

    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        children: [
          const SectionHeader(title: 'Aparência'),
          Card(
            child: Column(
              children: ThemeMode.values
                  .map(
                    (mode) => RadioListTile<ThemeMode>(
                      value: mode,
                      groupValue: settings.themeMode,
                      onChanged: (value) {
                        if (value != null) settings.setThemeMode(value);
                      },
                      title: Text(_themeLabel(mode)),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  String _themeLabel(ThemeMode mode) => switch (mode) {
    ThemeMode.system => 'Padrão do sistema',
    ThemeMode.light => 'Claro',
    ThemeMode.dark => 'Escuro',
  };
}
