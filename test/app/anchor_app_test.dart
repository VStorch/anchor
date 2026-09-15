import 'package:anchor/app/anchor_app.dart';
import 'package:anchor/core/database/app_database.dart';
import 'package:anchor/core/state/data_changes.dart';
import 'package:anchor/core/widgets/anchor_logo.dart';
import 'package:anchor/core/widgets/section_header.dart';
import 'package:anchor/features/dashboard/views/widgets/forecast_card.dart';
import 'package:anchor/features/dashboard/views/widgets/month_so_far_card.dart';
import 'package:anchor/features/dashboard/views/widgets/today_card.dart';
import 'package:anchor/core/utils/money.dart';
import 'package:anchor/core/utils/month.dart';
import 'package:anchor/features/expenses/models/expense.dart';
import 'package:anchor/features/expenses/models/expense_type.dart';
import 'package:anchor/features/expenses/repositories/expense_repository.dart';
import 'package:anchor/features/reminders/models/reminder_lead.dart';
import 'package:anchor/features/settings/viewmodels/settings_view_model.dart';
import 'package:anchor/features/wallets/models/payout.dart';
import 'package:anchor/features/wallets/models/wallet.dart';
import 'package:anchor/features/wallets/models/wallet_kind.dart';
import 'package:anchor/features/wallets/repositories/wallet_repository.dart';
import 'package:anchor/features/wallets/views/widgets/wallet_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_reminder_notifications.dart';
import '../support/test_database.dart';
import '../support/wallet_seed.dart';

void main() {
  late AppDatabase database;

  setUpAll(() => initializeDateFormatting('pt_BR'));

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    database = createInMemoryDatabase();
  });

  tearDown(() => database.close());

  Future<void> pumpApp(WidgetTester tester) async {
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

  bool focusOfField(WidgetTester tester) =>
      tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus;

  Future<void> tapTab(WidgetTester tester, IconData icon) async {
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.byIcon(icon),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> seedSalaryAndExpense({bool confirmSalary = true}) async {
    final changes = DataChanges();
    final wallets = WalletRepository(database, changes);
    final expenses = ExpenseRepository(database, changes);

    final today = DateTime.now();
    final walletId = await wallets.saveWallet(
      Wallet(
        name: 'Salário',
        kind: WalletKind.salary,
        colorIndex: 0,
        createdAt: DateTime(today.year, today.month),
      ),
    );
    await wallets.savePayout(
      Payout(
        walletId: walletId,
        label: 'Mensal',
        amount: 3000,
        day: 1,
        createdAt: DateTime(today.year, today.month),
      ),
    );
    if (confirmSalary) {
      await confirmDuePayouts(wallets);
    } else {
      await wallets.registerDuePayouts(await wallets.fetchWallets());
    }
    await expenses.saveExpense(
      Expense(
        name: 'Plano de saúde',
        type: ExpenseType.recurring,
        amount: 450,
        dueDay: 10,
        startMonth: Month.current(),
        walletId: walletId,
        createdAt: DateTime.now(),
      ),
    );
  }

  testWidgets('mostra a logo enquanto carrega', (tester) async {
    final settings = SettingsViewModel();
    await settings.initialize();

    await tester.pumpWidget(
      AnchorApp(
        reminderNotifications: FakeReminderNotifications(),
        settings: settings,
        database: database,
      ),
    );

    expect(find.byType(AnchorLogo), findsOneWidget);

    await tester.pumpAndSettle();
  });

  testWidgets('convida a cadastrar o salário quando não há carteiras', (
    tester,
  ) async {
    await pumpApp(tester);

    expect(find.text('Vamos ancorar seu mês'), findsOneWidget);
    expect(find.text('Cadastrar meu salário'), findsOneWidget);
  });

  testWidgets('a capa separa o que se tem hoje, a previsão e o mês', (
    tester,
  ) async {
    await seedSalaryAndExpense();
    await pumpApp(tester);

    final monthName = DateFormat.MMMM('pt_BR').format(DateTime.now());

    expect(
      find.descendant(
        of: find.byType(TodayCard),
        matching: find.text('Você tem hoje'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(TodayCard),
        matching: find.textContaining('3.000,00'),
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Confirmar'), findsNothing);

    final forecast = find.byType(ForecastCard);
    expect(
      find.descendant(
        of: forecast,
        matching: find.text('Previsão até o fim de $monthName'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: forecast,
        matching: find.text('Vai sobrar ${formatMoney(2550)}'),
      ),
      findsOneWidget,
    );

    final month = find.byType(MonthSoFarCard);
    expect(
      find.descendant(of: month, matching: find.textContaining('até agora')),
      findsOneWidget,
    );
    for (final label in ['Entrou', 'Saiu', 'Diferença']) {
      expect(
        find.descendant(of: month, matching: find.text(label)),
        findsOneWidget,
      );
    }
    expect(find.text('Sobrou'), findsNothing);

    await tester.scrollUntilVisible(
      find.text('Ver todas'),
      200,
      scrollable: find.byType(Scrollable).first,
    );

    expect(
      find.descendant(
        of: find.widgetWithText(SectionHeader, 'A pagar'),
        matching: find.textContaining('450,00 a pagar'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('a previsão abre o detalhe por carteira', (tester) async {
    await seedSalaryAndExpense();
    await pumpApp(tester);

    expect(find.text('A receber'), findsNothing);

    await tester.tap(find.text('Como chegamos nisso'));
    await tester.pumpAndSettle();

    final forecast = find.byType(ForecastCard);
    expect(
      find.descendant(of: forecast, matching: find.text('+ ${formatMoney(0)}')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: forecast,
        matching: find.text('− ${formatMoney(450)}'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: forecast, matching: find.text('Salário')),
      findsOneWidget,
    );
  });

  testWidgets('a previsão some no mês passado e o mês some no futuro', (
    tester,
  ) async {
    await seedSalaryAndExpense();
    await pumpApp(tester);

    await tester.tap(find.byTooltip('Próximo mês'));
    await tester.pumpAndSettle();

    expect(find.byType(ForecastCard), findsOneWidget);
    expect(find.byType(MonthSoFarCard), findsNothing);
    expect(find.byType(TodayCard), findsOneWidget);

    await tester.tap(find.byTooltip('Mês anterior'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Mês anterior'));
    await tester.pumpAndSettle();

    final previous = Month.current().previous;
    expect(find.byType(ForecastCard), findsNothing);
    expect(find.text(previous.label), findsWidgets);
    expect(find.byType(MonthSoFarCard), findsOneWidget);
  });

  testWidgets('a entrada a confirmar leva para as carteiras', (tester) async {
    await seedSalaryAndExpense(confirmSalary: false);
    await pumpApp(tester);

    expect(
      find.descendant(
        of: find.byType(TodayCard),
        matching: find.text(formatMoney(0)),
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Confirmar ${formatMoney(3000)}'));
    await tester.pumpAndSettle();

    expect(find.text('Saldo total'), findsOneWidget);
  });

  testWidgets('lista a despesa do mês na aba Despesas', (tester) async {
    await seedSalaryAndExpense();
    await pumpApp(tester);

    await tapTab(tester, Icons.receipt_long_outlined);

    expect(find.text('Falta pagar'), findsOneWidget);
    expect(find.text('Plano de saúde'), findsOneWidget);
    expect(find.text('Pagar'), findsOneWidget);
  });

  testWidgets('exclui a carteira a partir do formulário', (tester) async {
    await seedSalaryAndExpense();
    await pumpApp(tester);

    await tapTab(tester, Icons.account_balance_wallet_outlined);
    await tester.tap(
      find.descendant(
        of: find.byType(WalletCard),
        matching: find.text('Salário'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Excluir carteira'));
    await tester.pumpAndSettle();

    expect(find.text('Excluir Salário?'), findsOneWidget);
    await tester.tap(find.text('Excluir'));
    await tester.pumpAndSettle();

    expect(find.text('Comece pelo dinheiro que entra'), findsOneWidget);
  });

  testWidgets('tirar o foco do campo ao tocar fora dele', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('Cadastrar meu salário'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    expect(focusOfField(tester), isTrue);

    await tester.tap(find.text('Calendário de recebimento'));
    await tester.pumpAndSettle();
    expect(focusOfField(tester), isFalse);
  });

  testWidgets('tirar o foco do campo ao rolar a tela', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('Cadastrar meu salário'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    expect(focusOfField(tester), isTrue);

    await tester.drag(find.byType(ListView), const Offset(0, -160));
    await tester.pumpAndSettle();
    expect(focusOfField(tester), isFalse);
  });

  testWidgets('navega entre as abas pela barra inferior', (tester) async {
    await seedSalaryAndExpense();
    await pumpApp(tester);

    await tapTab(tester, Icons.account_balance_wallet_outlined);
    expect(find.text('Saldo total'), findsOneWidget);

    await tapTab(tester, Icons.tune_outlined);
    expect(find.text('Padrão do sistema'), findsOneWidget);
  });

  testWidgets('escolhe a antecedência do lembrete no Ajustes', (tester) async {
    await seedSalaryAndExpense();
    final notifications = FakeReminderNotifications();
    final settings = SettingsViewModel();
    await settings.initialize();
    await tester.pumpWidget(
      AnchorApp(
        reminderNotifications: notifications,
        settings: settings,
        database: database,
      ),
    );
    await tester.pumpAndSettle();
    await tapTab(tester, Icons.tune_outlined);

    await tester.tap(find.text('No dia'));
    await tester.pumpAndSettle();

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('reminders_lead'), 'sameDay');
    expect(notifications.scheduled, isNotEmpty);
    expect(
      notifications.scheduled.every((r) => r.title.endsWith('hoje')),
      isTrue,
    );

    await tester.tap(find.text('Avisar sobre vencimentos'));
    await tester.pumpAndSettle();
    final lead = tester.widget<SegmentedButton<ReminderLead>>(
      find.byType(SegmentedButton<ReminderLead>),
    );
    expect(lead.onSelectionChanged, isNull);
  });
}
