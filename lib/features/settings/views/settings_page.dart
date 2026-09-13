import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/database/database_backup.dart';
import '../../../core/widgets/section_header.dart';
import '../../reminders/models/due_reminder.dart';
import '../../reminders/viewmodels/reminders_view_model.dart';
import '../viewmodels/backup_view_model.dart';
import '../viewmodels/settings_view_model.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsViewModel>();
    final backup = context.watch<BackupViewModel>();
    final reminders = context.watch<RemindersViewModel>();

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
          const SectionHeader(title: 'Lembretes'),
          Card(
            child: SwitchListTile(
              value: reminders.isEnabled,
              onChanged: (value) => _setReminders(context, reminders, value),
              secondary: const Icon(Icons.notifications_outlined),
              title: const Text('Avisar no dia do vencimento'),
              subtitle: Text(
                'Às ${DueReminder.hourOfDay}h, se ainda não foi paga',
              ),
            ),
          ),
          const SectionHeader(title: 'Cópia dos dados'),
          Card(
            child: Column(
              children: [
                ListTile(
                  enabled: !backup.isBusy,
                  leading: const Icon(Icons.save_alt),
                  title: const Text('Salvar cópia'),
                  subtitle: Text(_lastSavedLabel(backup.lastSavedAt)),
                  onTap: () => _save(context, backup),
                ),
                ListTile(
                  enabled: !backup.isBusy,
                  leading: const Icon(Icons.settings_backup_restore),
                  title: const Text('Restaurar cópia'),
                  onTap: () => _restore(context, backup),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _setReminders(
    BuildContext context,
    RemindersViewModel reminders,
    bool value,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    if (!await reminders.setEnabled(value)) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Libere as notificações do Anchor nos ajustes do Android',
          ),
        ),
      );
    }
  }

  Future<void> _save(BuildContext context, BackupViewModel backup) async {
    final messenger = ScaffoldMessenger.of(context);
    if (await backup.save()) {
      messenger.showSnackBar(const SnackBar(content: Text('Cópia salva')));
    }
  }

  Future<void> _restore(BuildContext context, BackupViewModel backup) async {
    final messenger = ScaffoldMessenger.of(context);

    final BackupContents? contents;
    try {
      contents = await backup.pick();
    } on BackupException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.problem.message)));
      return;
    }
    if (contents == null || !context.mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restaurar esta cópia?'),
        content: Text(
          '${_count(contents!.walletCount, 'carteira', 'carteiras')} e '
          '${_count(contents.expenseCount, 'despesa', 'despesas')} '
          'substituem tudo o que está no app agora.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Restaurar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await backup.restore(contents);
    messenger.showSnackBar(const SnackBar(content: Text('Cópia restaurada')));
  }

  String _lastSavedLabel(DateTime? savedAt) => savedAt == null
      ? 'Nenhuma ainda'
      : 'Última em ${DateFormat.MMMd('pt_BR').format(savedAt)}';

  String _count(int count, String singular, String plural) =>
      '$count ${count == 1 ? singular : plural}';

  String _themeLabel(ThemeMode mode) => switch (mode) {
    ThemeMode.system => 'Padrão do sistema',
    ThemeMode.light => 'Claro',
    ThemeMode.dark => 'Escuro',
  };
}
