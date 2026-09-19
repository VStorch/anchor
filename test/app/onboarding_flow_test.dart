import 'package:anchor/app/anchor_app.dart';
import 'package:anchor/core/database/app_database.dart';
import 'package:anchor/core/state/data_changes.dart';
import 'package:anchor/core/utils/money.dart';
import 'package:anchor/features/dashboard/views/dashboard_page.dart';
import 'package:anchor/features/dashboard/views/widgets/today_card.dart';
import 'package:anchor/features/expenses/repositories/expense_repository.dart';
import 'package:anchor/features/onboarding/views/onboarding_page.dart';
import 'package:anchor/features/settings/viewmodels/settings_view_model.dart';
import 'package:anchor/features/wallets/models/payout.dart';
import 'package:anchor/features/wallets/models/wallet.dart';
import 'package:anchor/features/wallets/models/wallet_kind.dart';
import 'package:anchor/features/wallets/repositories/wallet_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_reminder_notifications.dart';
import '../support/onboarding_driver.dart';
import '../support/test_database.dart';

void main() {
  final now = DateTime(2026, 9, 15, 10);

  late AppDatabase database;
  late FakeReminderNotifications notifications;

  setUpAll(() => initializeDateFormatting('pt_BR'));

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    database = createInMemoryDatabase();
    notifications = FakeReminderNotifications();
  });

  tearDown(() => database.close());

  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final settings = SettingsViewModel();
    await settings.initialize();
    await tester.pumpWidget(
      AnchorApp(
        reminderNotifications: notifications,
        settings: settings,
        database: database,
        clock: () => now,
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a configuração inicial chega ao Resumo com o saldo intacto', (
    tester,
  ) async {
    await pumpApp(tester);
    expect(find.byType(OnboardingPage), findsOneWidget);

    await fillOnboarding(tester);
    expect(notifications.permissionRequests, 0);
    await tapVisible(tester, find.text('Ativar lembretes'));

    expect(find.byType(OnboardingPage), findsNothing);
    expect(notifications.permissionRequests, 1);

    final dashboard = find.byType(DashboardPage);
    expect(
      find.descendant(
        of: find.byType(TodayCard),
        matching: find.text(formatMoney(1150)),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(TodayCard),
        matching: find.text('Confirmar ${formatMoney(600)}'),
      ),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.descendant(of: dashboard, matching: find.text('Internet')),
      200,
      scrollable: find
          .descendant(of: dashboard, matching: find.byType(Scrollable))
          .first,
    );
    expect(
      find.descendant(of: dashboard, matching: find.text('Aluguel')),
      findsNothing,
    );

    final wallets = await WalletRepository(
      database,
      DataChanges(),
    ).fetchWallets();
    expect(wallets.map((wallet) => wallet.name), ['Salário', 'VR', 'VA']);

    final expenses = ExpenseRepository(database, DataChanges());
    final rent = (await expenses.fetchExpenses()).firstWhere(
      (expense) => expense.name == 'Aluguel',
    );
    final rentPayments = (await expenses.fetchPayments()).where(
      (payment) => payment.expenseId == rent.id,
    );
    expect(rentPayments.single.amount, 1100);
    expect(notifications.scheduled, isNotEmpty);

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getBool('onboarding_done'), isTrue);
  });

  testWidgets('pular a configuração abre o app vazio e não volta mais', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(find.text('Pular configuração'));
    await tester.pumpAndSettle();

    expect(find.byType(OnboardingPage), findsNothing);
    expect(find.text('Vamos ancorar seu mês'), findsOneWidget);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getBool('onboarding_done'), isTrue);
  });

  testWidgets('sair no meio pede confirmação e não salva o que foi digitado', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(find.text('Começar'));
    await tester.pumpAndSettle();
    await typeMoney(
      tester,
      within: find.byKey(const ValueKey('income-salary')),
      '3200',
    );

    await tester.tap(find.text('Pular configuração'));
    await tester.pumpAndSettle();
    expect(find.text('Sair da configuração?'), findsOneWidget);
    await tester.tap(find.text('Continuar configurando'));
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingPage), findsOneWidget);

    await tester.tap(find.text('Pular configuração'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sair'));
    await tester.pumpAndSettle();

    expect(find.byType(OnboardingPage), findsNothing);
    expect(
      await WalletRepository(database, DataChanges()).fetchWallets(),
      isEmpty,
    );
  });

  testWidgets('voltar do celular volta um passo', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Começar'));
    await tester.pumpAndSettle();
    expect(find.text('Quanto você recebe?'), findsOneWidget);

    await tester.tap(find.text('Pular'));
    await tester.pumpAndSettle();
    expect(find.text('Contas de todo mês'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Quanto você recebe?'), findsOneWidget);
  });

  testWidgets('quem já tem carteira nunca vê a configuração', (tester) async {
    await WalletRepository(database, DataChanges()).saveWalletWithPayouts(
      Wallet(
        name: 'Salário',
        kind: WalletKind.salary,
        colorIndex: 0,
        createdAt: now,
      ),
      payouts: [
        Payout(
          walletId: 0,
          label: 'Mensal',
          amount: 3000,
          day: 1,
          createdAt: now,
        ),
      ],
    );

    await pumpApp(tester);

    expect(find.byType(OnboardingPage), findsNothing);
    expect(find.byType(TodayCard), findsOneWidget);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getBool('onboarding_done'), isTrue);
  });
}
