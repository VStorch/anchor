import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import '../core/database/app_database.dart';
import '../core/database/database_backup.dart';
import '../core/state/data_changes.dart';
import '../core/state/month_selection.dart';
import '../core/widgets/dismiss_focus.dart';
import '../features/budget/services/budget_service.dart';
import '../features/cards/repositories/card_repository.dart';
import '../features/dashboard/viewmodels/dashboard_view_model.dart';
import '../features/expenses/repositories/expense_repository.dart';
import '../features/expenses/viewmodels/expenses_view_model.dart';
import '../features/reminders/services/reminder_notifications.dart';
import '../features/reminders/viewmodels/reminders_view_model.dart';
import '../features/settings/services/backup_files.dart';
import '../features/settings/viewmodels/backup_view_model.dart';
import '../features/settings/viewmodels/settings_view_model.dart';
import '../features/wallets/repositories/wallet_repository.dart';
import '../features/wallets/viewmodels/wallets_view_model.dart';
import 'app_shell.dart';
import 'theme/app_theme.dart';

class AnchorApp extends StatelessWidget {
  const AnchorApp({
    super.key,
    required this.settings,
    AppDatabase? database,
    BackupFiles backupFiles = const DeviceBackupFiles(),
    ReminderNotifications? reminderNotifications,
  }) : _database = database,
       _backupFiles = backupFiles,
       _reminderNotifications = reminderNotifications;

  final SettingsViewModel settings;
  final AppDatabase? _database;
  final BackupFiles _backupFiles;
  final ReminderNotifications? _reminderNotifications;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settings),
        ChangeNotifierProvider(create: (_) => AppShellController()),
        ChangeNotifierProvider(create: (_) => DataChanges()),
        ChangeNotifierProvider(create: (_) => MonthSelection()),
        Provider<AppDatabase>.value(value: _database ?? AppDatabase.instance),
        ProxyProvider2<AppDatabase, DataChanges, ExpenseRepository>(
          update: (_, database, changes, __) =>
              ExpenseRepository(database, changes),
        ),
        ProxyProvider2<AppDatabase, DataChanges, WalletRepository>(
          update: (_, database, changes, __) =>
              WalletRepository(database, changes),
        ),
        ProxyProvider2<AppDatabase, DataChanges, CardRepository>(
          update: (_, database, changes, __) =>
              CardRepository(database, changes),
        ),
        ProxyProvider3<
          ExpenseRepository,
          WalletRepository,
          CardRepository,
          BudgetService
        >(
          update: (_, expenses, wallets, cards, __) =>
              BudgetService(expenses, wallets, cards),
        ),
        ChangeNotifierProvider(
          create: (context) => DashboardViewModel(
            budgetService: context.read<BudgetService>(),
            monthSelection: context.read<MonthSelection>(),
            changes: context.read<DataChanges>(),
          )..initialize(),
        ),
        ChangeNotifierProvider(
          create: (context) => ExpensesViewModel(
            budgetService: context.read<BudgetService>(),
            expenseRepository: context.read<ExpenseRepository>(),
            monthSelection: context.read<MonthSelection>(),
            changes: context.read<DataChanges>(),
          )..initialize(),
        ),
        ChangeNotifierProvider(
          create: (context) => WalletsViewModel(
            budgetService: context.read<BudgetService>(),
            walletRepository: context.read<WalletRepository>(),
            monthSelection: context.read<MonthSelection>(),
            changes: context.read<DataChanges>(),
          )..initialize(),
        ),
        ChangeNotifierProvider(
          create: (context) => BackupViewModel(
            backup: DatabaseBackup(context.read<AppDatabase>()),
            files: _backupFiles,
            changes: context.read<DataChanges>(),
          )..initialize(),
        ),
        ChangeNotifierProvider(
          lazy: false,
          create: (context) => RemindersViewModel(
            budgetService: context.read<BudgetService>(),
            notifications:
                _reminderNotifications ?? LocalReminderNotifications(),
            changes: context.read<DataChanges>(),
          )..initialize(),
        ),
      ],
      child: Consumer<SettingsViewModel>(
        builder: (context, settings, _) => MaterialApp(
          title: 'Anchor',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: settings.themeMode,
          locale: const Locale('pt', 'BR'),
          supportedLocales: const [Locale('pt', 'BR')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (context, child) => DismissFocus(child: child!),
          home: const AppShell(),
        ),
      ),
    );
  }
}
