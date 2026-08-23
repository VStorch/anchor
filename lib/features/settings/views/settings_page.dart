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
          const SectionHeader(
            title: 'Aparência',
            subtitle: 'Escolha como o Anchor deve se apresentar',
          ),
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
                      subtitle: Text(_themeDescription(mode)),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 24),
          const SectionHeader(title: 'Sobre'),
          const Card(
            child: ListTile(
              leading: Icon(Icons.anchor_outlined),
              title: Text('Anchor'),
              subtitle: Text(
                'Gerenciamento de dinheiro com foco no que realmente sai da sua conta.',
              ),
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

  String _themeDescription(ThemeMode mode) => switch (mode) {
    ThemeMode.system => 'Acompanha a configuração do seu aparelho',
    ThemeMode.light => 'Tons de verde sobre fundo claro',
    ThemeMode.dark => 'Tons de verde sobre fundo escuro',
  };
}
