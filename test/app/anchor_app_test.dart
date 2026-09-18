import 'package:anchor/app/anchor_app.dart';
import 'package:anchor/core/database/app_database.dart';
import 'package:anchor/core/state/data_changes.dart';
import 'package:anchor/core/widgets/anchor_logo.dart';
import 'package:anchor/core/widgets/section_header.dart';
import 'package:anchor/features/dashboard/views/widgets/daily_spending_sheet.dart';
import 'package:anchor/features/dashboard/views/widgets/forecast_card.dart';
import 'package:anchor/features/dashboard/views/widgets/month_so_far_card.dart';
import 'package:anchor/features/dashboard/views/widgets/today_card.dart';
import 'package:anchor/core/utils/money.dart';
import 'package:anchor/core/utils/month.dart';
import 'package:anchor/features/expenses/models/expense.dart';
import 'package:anchor/features/expenses/models/expense_payment.dart';
import 'package:anchor/features/expenses/models/expense_type.dart';
import 'package:anchor/features/expenses/repositories/expense_repository.dart';
import 'package:anchor/features/reminders/models/reminder_lead.dart';
import 'package:anchor/features/reminders/views/notifications_blocked_notice.dart';
import 'package:anchor/features/settings/viewmodels/settings_view_model.dart';
import 'package:anchor/features/wallets/models/balance_check.dart';
import 'package:anchor/features/wallets/models/outflow.dart';
import 'package:anchor/features/wallets/models/payout.dart';
import 'package:anchor/features/wallets/models/payout_schedule.dart';
import 'package:anchor/features/wallets/models/receipt_status.dart';
import 'package:anchor/features/wallets/models/wallet.dart';
import 'package:anchor/features/wallets/models/wallet_kind.dart';
import 'package:anchor/features/wallets/repositories/wallet_repository.dart';
import 'package:anchor/features/wallets/views/wallets_page.dart';
import 'package:anchor/features/wallets/views/widgets/wallet_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_reminder_notifications.dart';
import '../support/preferences.dart';
import '../support/test_database.dart';
import '../support/wallet_seed.dart';

void main() {
  late AppDatabase database;

  setUpAll(() => initializeDateFormatting('pt_BR'));

  setUp(() {
    mockPreferences();
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

  bool focusOfField(WidgetTester tester) => tester
      .widget<EditableText>(find.byType(EditableText).first)
      .focusNode
      .hasFocus;

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

  testWidgets('a aba Carteiras vazia não tem botão de gasto', (tester) async {
    await pumpApp(tester);
    await tapTab(tester, Icons.account_balance_wallet_outlined);

    expect(find.text('Comece pelo dinheiro que entra'), findsOneWidget);
    expect(find.text('Cadastrar salário ou benefício'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);
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
        matching: find.text('Dinheiro livre vai sobrar ${formatMoney(2550)}'),
      ),
      findsOneWidget,
    );

    final month = find.byType(MonthSoFarCard);
    await tester.scrollUntilVisible(
      month,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.descendant(of: month, matching: find.textContaining('até agora')),
      findsOneWidget,
    );
    for (final label in ['Entrou', 'Saiu', 'Somou ao saldo']) {
      expect(
        find.descendant(of: month, matching: find.text(label)),
        findsOneWidget,
      );
    }
    expect(find.text('Diferença'), findsNothing);
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

  Future<void> seedMariana(DateTime today) async {
    final changes = DataChanges();
    final wallets = WalletRepository(database, changes);
    final expenses = ExpenseRepository(database, changes);
    final month = Month.fromDate(today);
    final start = DateTime(today.year, today.month);

    Future<int> source(String name, WalletKind kind) => wallets.saveWallet(
      Wallet(
        name: name,
        kind: kind,
        colorIndex: kind == WalletKind.salary ? 0 : 1,
        createdAt: start,
      ),
    );

    final salaryId = await source('Salário', WalletKind.salary);
    final voucherId = await source('VR', WalletKind.benefit);
    await wallets.savePayout(
      Payout(
        walletId: salaryId,
        label: '',
        amount: 3200,
        day: 5,
        schedule: PayoutSchedule.businessDay,
        createdAt: start,
      ),
    );
    await wallets.savePayout(
      Payout(
        walletId: voucherId,
        label: '',
        amount: 600,
        day: 1,
        createdAt: start,
      ),
    );
    await wallets.registerDuePayouts(await wallets.fetchWallets(), now: today);
    for (final receipt in await wallets.fetchReceipts()) {
      await wallets.saveReceipt(
        receipt.copyWith(status: ReceiptStatus.confirmed),
      );
    }

    final checkedAt = DateTime(today.year, today.month, today.day, 9, 4);
    await wallets.saveBalanceCheck(
      BalanceCheck(walletId: salaryId, amount: 850, checkedAt: checkedAt),
    );
    await wallets.saveBalanceCheck(
      BalanceCheck(walletId: voucherId, amount: 210, checkedAt: checkedAt),
    );

    final bills = <String, (double, int, DateTime)>{
      'Aluguel': (1100, 10, DateTime(2026, 9, 10, 12)),
      'Celular': (89, 12, DateTime(2026, 9, 12, 12)),
      'Academia': (110, 5, DateTime(2026, 9, 5, 12)),
      'Geladeira': (115, 14, DateTime(2026, 9, 14, 12)),
      'Internet': (99.90, 15, DateTime(2026, 9, 15, 10)),
    };
    for (final bill in bills.entries) {
      final (amount, dueDay, paidAt) = bill.value;
      final expenseId = await expenses.saveExpense(
        Expense(
          name: bill.key,
          type: ExpenseType.recurring,
          amount: amount,
          dueDay: dueDay,
          startMonth: month,
          walletId: salaryId,
          createdAt: start,
        ),
      );
      await expenses.savePayment(
        ExpensePayment(
          expenseId: expenseId,
          walletId: salaryId,
          month: month,
          amount: amount,
          paidAt: paidAt,
        ),
      );
    }

    await wallets.saveOutflow(
      Outflow(
        walletId: voucherId,
        description: 'Mercado',
        amount: 47.30,
        spentAt: DateTime(2026, 9, 15, 12),
      ),
    );
  }

  testWidgets('o saldo de hoje se explica e o mês não vira sobra', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    final today = DateTime(2026, 9, 15, 14);
    await seedMariana(today);

    final settings = SettingsViewModel();
    await settings.initialize();
    await tester.pumpWidget(
      AnchorApp(
        reminderNotifications: FakeReminderNotifications(),
        settings: settings,
        database: database,
        clock: () => today,
      ),
    );
    await tester.pumpAndSettle();

    final card = find.byType(TodayCard);
    expect(
      find.descendant(of: card, matching: find.text(formatMoney(912.80))),
      findsOneWidget,
    );

    await tester.tap(find.text('De onde vem esse valor'));
    await tester.pumpAndSettle();

    Finder inCard(String text) =>
        find.descendant(of: card, matching: find.text(text));

    expect(inCard('Saldo informado em 15/09, 9h04'), findsNWidgets(2));
    expect(inCard('Saiu depois'), findsNWidgets(2));
    expect(inCard('Salário'), findsOneWidget);
    expect(inCard(formatMoney(750.10)), findsOneWidget);
    expect(inCard('− ${formatMoney(99.90)}'), findsOneWidget);
    expect(inCard('VR'), findsOneWidget);
    expect(inCard(formatMoney(162.70)), findsOneWidget);
    expect(inCard('− ${formatMoney(47.30)}'), findsOneWidget);

    final forecast = find.byType(ForecastCard);
    await tester.scrollUntilVisible(
      forecast,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.descendant(
        of: forecast,
        matching: find.text('Dinheiro livre vai sobrar ${formatMoney(750.10)}'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: forecast,
        matching: find.text('Nos benefícios: ${formatMoney(162.70)} para usar'),
      ),
      findsOneWidget,
    );
    expect(
      find.text("Dinheiro livre vai sobrar ${formatMoney(912.80)}"),
      findsNothing,
    );

    final month = find.byType(MonthSoFarCard);
    await tester.scrollUntilVisible(
      month,
      200,
      scrollable: find.byType(Scrollable).first,
    );

    expect(
      find.descendant(of: month, matching: find.text(formatMoney(3800))),
      findsOneWidget,
    );
    expect(
      find.descendant(of: month, matching: find.text(formatMoney(1561.20))),
      findsOneWidget,
    );
    expect(find.text('Diferença'), findsNothing);
    expect(find.text('Somou ao saldo'), findsNothing);
    expect(
      find.text(
        '${formatMoney(3800)} do que entrou e ${formatMoney(1414)} do que '
        'saiu já estavam no saldo que você informou em 15/09.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('reservar o gasto do dia a dia muda a previsão', (tester) async {
    await seedSalaryAndExpense();
    await pumpApp(tester);

    final forecast = find.byType(ForecastCard);
    expect(
      find.descendant(
        of: forecast,
        matching: find.text(
          'A previsão ainda não conta mercado, transporte e '
          'lanches.',
        ),
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Reservar gasto do dia a dia'));
    await tester.pumpAndSettle();

    expect(find.byType(DailySpendingSheet), findsOneWidget);
    expect(
      find.textContaining('gastos no Salário ou no cartão pago por ele'),
      findsOneWidget,
    );
    await tester.enterText(
      find.descendant(
        of: find.byType(DailySpendingSheet),
        matching: find.byType(TextField),
      ),
      '500',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salvar reserva'));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: forecast,
        matching: find.text('Dinheiro livre vai sobrar ${formatMoney(2050)}'),
      ),
      findsOneWidget,
    );
    expect(find.text('Reservar gasto do dia a dia'), findsNothing);

    await tester.tap(find.text('Como chegamos nisso'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: forecast,
        matching: find.text('Reserva do dia a dia'),
      ),
      findsOneWidget,
    );

    await tester.ensureVisible(find.byTooltip('Editar reserva'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Editar reserva'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Não usar reserva'));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: forecast,
        matching: find.text('Dinheiro livre vai sobrar ${formatMoney(2550)}'),
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
    final total = find.descendant(
      of: forecast,
      matching: find.text(formatMoney(2550)),
    );
    expect(total, findsOneWidget);
    expect(
      find.descendant(of: forecast, matching: find.text('Vai sobrar')),
      findsOneWidget,
      reason: 'o bloco fecha no mesmo valor do título',
    );
    expect(
      find.descendant(of: forecast, matching: find.text('Benefícios')),
      findsNothing,
    );
  });

  testWidgets('a conta sem carteira aparece antes do total do dinheiro livre', (
    tester,
  ) async {
    await seedSalaryAndExpense();
    await ExpenseRepository(database, DataChanges()).saveExpense(
      Expense(
        name: 'IPTU',
        type: ExpenseType.single,
        amount: 50,
        dueDay: 28,
        startMonth: Month.current(),
        createdAt: DateTime.now(),
      ),
    );
    await pumpApp(tester);

    await tester.tap(find.text('Como chegamos nisso'));
    await tester.pumpAndSettle();

    final forecast = find.byType(ForecastCard);
    final unassigned = find.descendant(
      of: forecast,
      matching: find.text('Contas sem carteira'),
    );
    final total = find.descendant(
      of: forecast,
      matching: find.text('Vai sobrar'),
    );
    expect(unassigned, findsOneWidget);
    expect(
      tester.getTopLeft(unassigned).dy,
      lessThan(tester.getTopLeft(total).dy),
    );
    expect(
      find.descendant(of: forecast, matching: find.text(formatMoney(2500))),
      findsWidgets,
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

    await tester.tap(
      find.descendant(
        of: find.byType(TodayCard),
        matching: find.text('Confirmar ${formatMoney(3000)}'),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(WalletsPage),
        matching: find.text('Você tem hoje'),
      ),
      findsOneWidget,
    );
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
    await tester.tap(find.byTooltip('Editar carteira'));
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

    await tester.tap(find.widgetWithText(TextField, 'Nome da carteira'));
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

    await tester.tap(find.widgetWithText(TextField, 'Nome da carteira'));
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
    expect(
      find.descendant(
        of: find.byType(WalletsPage),
        matching: find.text('Você tem hoje'),
      ),
      findsOneWidget,
    );

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

  testWidgets('o Ajustes avisa quando o Android bloqueia as notificações', (
    tester,
  ) async {
    final settings = SettingsViewModel();
    await settings.initialize();
    await tester.pumpWidget(
      AnchorApp(
        reminderNotifications: FakeReminderNotifications(systemEnabled: false),
        settings: settings,
        database: database,
      ),
    );
    await tester.pumpAndSettle();
    await tapTab(tester, Icons.tune_outlined);

    expect(find.byType(NotificationsBlockedNotice), findsOneWidget);
    expect(
      find.textContaining('Ajustes do Android › Apps › Anchor'),
      findsOneWidget,
    );
  });

  testWidgets('voltar ao app depois de ligar as notificações tira o aviso', (
    tester,
  ) async {
    final notifications = FakeReminderNotifications(systemEnabled: false);
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
    expect(find.byType(NotificationsBlockedNotice), findsOneWidget);

    notifications.systemEnabled = true;
    for (final state in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    await tester.pumpAndSettle();

    expect(find.byType(NotificationsBlockedNotice), findsNothing);
  });
}
