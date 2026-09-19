import 'package:anchor/app/anchor_app.dart';
import 'package:anchor/core/database/app_database.dart';
import 'package:anchor/core/state/data_changes.dart';
import 'package:anchor/core/utils/month.dart';
import 'package:anchor/features/expenses/models/expense.dart';
import 'package:anchor/features/expenses/models/expense_type.dart';
import 'package:anchor/features/expenses/repositories/expense_repository.dart';
import 'package:anchor/features/settings/models/app_tip.dart';
import 'package:anchor/features/settings/viewmodels/settings_view_model.dart';
import 'package:anchor/features/wallets/models/payout.dart';
import 'package:anchor/features/wallets/models/wallet.dart';
import 'package:anchor/features/wallets/models/wallet_kind.dart';
import 'package:anchor/features/wallets/repositories/wallet_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../support/fake_reminder_notifications.dart';
import '../support/preferences.dart';
import '../support/test_database.dart';

void main() {
  late AppDatabase database;

  setUpAll(() => initializeDateFormatting('pt_BR'));

  setUp(() {
    mockPreferences(<String, Object>{'seen_tips': <String>[]});
    database = createInMemoryDatabase();
  });

  tearDown(() => database.close());

  Future<void> seed() async {
    final now = DateTime.now();
    final changes = DataChanges();
    final walletId = await WalletRepository(database, changes)
        .saveWalletWithPayouts(
          Wallet(
            name: 'Salário',
            kind: WalletKind.salary,
            colorIndex: 0,
            createdAt: now,
          ),
          payouts: [
            Payout(
              walletId: 0,
              label: '',
              amount: 3000,
              day: 5,
              createdAt: now,
            ),
          ],
        );
    await ExpenseRepository(database, changes).saveExpense(
      Expense(
        name: 'Luz',
        type: ExpenseType.recurring,
        amount: 150,
        dueDay: 20,
        startMonth: Month.fromDate(now),
        walletId: walletId,
        createdAt: now,
      ),
    );
  }

  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final settings = SettingsViewModel();
    await settings.initialize();
    await tester.pumpWidget(
      AnchorApp(
        reminderNotifications: FakeReminderNotifications(),
        settings: settings,
        database: database,
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapTab(WidgetTester tester, String label) async {
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text(label),
      ),
    );
    await tester.pumpAndSettle();
  }

  const tabs = <(String, AppTip)>[
    ('Resumo', AppTip.dashboard),
    ('Despesas', AppTip.expenses),
    ('Carteiras', AppTip.wallets),
  ];

  testWidgets(
    'cada aba mostra a dica uma vez e Rever dicas traz todas de volta',
    (tester) async {
      await seed();
      await pumpApp(tester);

      for (final (tab, tip) in tabs) {
        await tapTab(tester, tab);
        expect(find.text(tip.message), findsOneWidget);
        await tester.tap(find.text('Entendi'));
        await tester.pumpAndSettle();
        expect(find.text(tip.message), findsNothing);
      }

      await tester.pumpWidget(const SizedBox());
      await pumpApp(tester);
      for (final (tab, tip) in tabs) {
        await tapTab(tester, tab);
        expect(find.text(tip.message), findsNothing);
      }

      await tapTab(tester, 'Ajustes');
      await tester.tap(find.text('Rever dicas'));
      await tester.pumpAndSettle();

      for (final (tab, tip) in tabs) {
        await tapTab(tester, tab);
        expect(find.text(tip.message), findsOneWidget);
      }
    },
  );

  testWidgets('a dica não aparece por cima do estado vazio', (tester) async {
    await pumpApp(tester);

    expect(find.text('Vamos ancorar seu mês'), findsOneWidget);
    for (final (tab, tip) in tabs) {
      await tapTab(tester, tab);
      expect(find.text(tip.message), findsNothing);
    }
  });
}
