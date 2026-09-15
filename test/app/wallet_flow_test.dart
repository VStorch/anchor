import 'package:anchor/app/anchor_app.dart';
import 'package:anchor/core/database/app_database.dart';
import 'package:anchor/core/state/data_changes.dart';
import 'package:anchor/core/utils/moment.dart';
import 'package:anchor/core/utils/money.dart';
import 'package:anchor/core/utils/month.dart';
import 'package:anchor/core/widgets/day_of_month_picker.dart';
import 'package:anchor/core/widgets/money_field.dart';
import 'package:anchor/features/dashboard/views/widgets/month_so_far_card.dart';
import 'package:anchor/features/dashboard/views/widgets/today_card.dart';
import 'package:anchor/features/settings/viewmodels/settings_view_model.dart';
import 'package:anchor/features/wallets/models/balance_check.dart';
import 'package:anchor/features/wallets/models/outflow.dart';
import 'package:anchor/features/wallets/models/payout.dart';
import 'package:anchor/features/wallets/models/payout_schedule.dart';
import 'package:anchor/features/wallets/models/receipt_status.dart';
import 'package:anchor/features/wallets/models/wallet.dart';
import 'package:anchor/features/wallets/models/wallet_kind.dart';
import 'package:anchor/features/wallets/repositories/wallet_repository.dart';
import 'package:anchor/features/wallets/views/widgets/balance_check_sheet.dart';
import 'package:anchor/features/wallets/views/widgets/payout_editor_sheet.dart';
import 'package:anchor/features/wallets/views/widgets/wallet_card.dart';
import 'package:anchor/features/wallets/views/widgets/outflow_sheet.dart';
import 'package:anchor/features/wallets/views/widgets/receipt_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_reminder_notifications.dart';
import '../support/test_database.dart';

void main() {
  late AppDatabase database;

  setUpAll(() => initializeDateFormatting('pt_BR'));

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    database = createInMemoryDatabase();
  });

  tearDown(() => database.close());

  Future<void> seedSalary({
    PayoutSchedule? schedule,
    double amount = 3000,
  }) async {
    final repository = WalletRepository(database, DataChanges());
    final today = DateTime.now();

    final walletId = await repository.saveWallet(
      Wallet(
        name: 'Salário',
        kind: WalletKind.salary,
        colorIndex: 0,
        createdAt: DateTime(today.year, today.month),
      ),
    );
    await repository.savePayout(
      Payout(
        walletId: walletId,
        label: 'Mensal',
        amount: amount,
        day: 1,
        schedule: schedule ?? PayoutSchedule.dayOfMonth,
        createdAt: DateTime(today.year, today.month),
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

    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.byIcon(Icons.account_balance_wallet_outlined),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> goToDashboard(WidgetTester tester) async {
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.byIcon(Icons.pie_chart_outline),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder moneyInput() => find.descendant(
    of: find.byType(MoneyField),
    matching: find.byType(TextField),
  );

  testWidgets('o saldo informado muda a capa sem virar entrada do mês', (
    tester,
  ) async {
    await seedSalary();
    await pumpApp(tester);

    await tester.tap(find.text('Saldo').first);
    await tester.pumpAndSettle();
    await tester.enterText(moneyInput(), '5200');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salvar saldo'));
    await tester.pumpAndSettle();

    await goToDashboard(tester);

    expect(
      find.descendant(
        of: find.byType(TodayCard),
        matching: find.textContaining('5.200,00'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(MonthSoFarCard),
        matching: find.textContaining('3.000,00'),
      ),
      findsWidgets,
    );
  });

  testWidgets('a entrada prevista não conta no saldo até ser confirmada', (
    tester,
  ) async {
    await seedSalary();
    await pumpApp(tester);

    final card = find.byType(WalletCard);
    expect(
      find.descendant(of: card, matching: find.text(formatMoney(0))),
      findsNWidgets(3),
    );
    expect(find.textContaining('a confirmar'), findsWidgets);
  });

  testWidgets('confirma a entrada prevista com o valor real', (tester) async {
    await seedSalary();
    await pumpApp(tester);

    final confirm = find.descendant(
      of: find.byType(WalletCard),
      matching: find.text('Confirmar ${formatMoney(3000)}'),
    );
    expect(confirm, findsOneWidget);

    await tester.tap(confirm);
    await tester.pumpAndSettle();

    expect(find.byType(ReceiptSheet), findsOneWidget);
    expect(find.text('Confirmar recebimento'), findsOneWidget);

    await tester.enterText(
      find.descendant(
        of: find.byType(MoneyField),
        matching: find.byType(TextField),
      ),
      '3120,45',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Confirmar recebimento'));
    await tester.pumpAndSettle();

    expect(find.textContaining('3.120,45'), findsWidgets);
    expect(find.textContaining('a confirmar'), findsNothing);
    expect(confirm, findsNothing);
  });

  testWidgets('informa o saldo e confirma o salário que já caiu', (
    tester,
  ) async {
    await seedSalary(amount: 3200);
    await pumpApp(tester);

    await tester.tap(find.text('Saldo').first);
    await tester.pumpAndSettle();

    expect(find.byType(BalanceCheckSheet), findsOneWidget);
    expect(find.text('Saldo de Salário'), findsOneWidget);
    expect(find.textContaining('O app calcula'), findsOneWidget);

    final arrived = find.byType(CheckboxListTile);
    expect(arrived, findsOneWidget);
    expect(
      find.descendant(of: arrived, matching: find.textContaining('já caiu')),
      findsOneWidget,
    );
    expect(tester.widget<CheckboxListTile>(arrived).value, isTrue);

    await tester.enterText(moneyInput(), '850');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salvar saldo'));
    await tester.pumpAndSettle();

    final walletCard = find.byType(WalletCard);
    expect(
      find.descendant(of: walletCard, matching: find.text(formatMoney(850))),
      findsOneWidget,
    );
    expect(
      find.descendant(of: walletCard, matching: find.text(formatMoney(3200))),
      findsOneWidget,
    );
    expect(find.textContaining('a confirmar'), findsNothing);
    expect(find.text('Saldo informado'), findsOneWidget);
    expect(find.textContaining('antes do saldo informado'), findsOneWidget);

    final receipt = (await WalletRepository(
      database,
      DataChanges(),
    ).fetchReceipts()).single;
    expect(receipt.status, ReceiptStatus.confirmed);

    await tester.tap(find.text('Gasto'));
    await tester.pumpAndSettle();
    await tester.enterText(moneyInput(), '47,90');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Registrar gasto'));
    await tester.pumpAndSettle();

    expect(
      find.descendant(of: walletCard, matching: find.text(formatMoney(802.10))),
      findsOneWidget,
    );
  });

  testWidgets('o salário desmarcado no saldo entra quando é confirmado', (
    tester,
  ) async {
    await seedSalary(amount: 3200);
    await pumpApp(tester);

    await tester.tap(find.text('Saldo').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    await tester.enterText(moneyInput(), '850');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salvar saldo'));
    await tester.pumpAndSettle();

    final walletCard = find.byType(WalletCard);
    expect(find.textContaining('a confirmar'), findsWidgets);

    await tester.tap(find.textContaining('a confirmar').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmar recebimento'));
    await tester.pumpAndSettle();

    expect(
      find.descendant(of: walletCard, matching: find.text(formatMoney(4050))),
      findsOneWidget,
    );
    expect(find.textContaining('antes do saldo informado'), findsNothing);
  });

  group('gasto no dia do saldo informado', () {
    Future<void> seedCheckYesterdayAt13() async {
      await seedSalary();
      final repository = WalletRepository(database, DataChanges());
      final today = DateTime.now();
      await repository.saveBalanceCheck(
        BalanceCheck(
          walletId: 1,
          amount: 500,
          checkedAt: DateTime(today.year, today.month, today.day - 1, 13),
        ),
      );
    }

    Future<void> launchYesterday(WidgetTester tester, String side) async {
      final today = DateTime.now();
      final yesterday = DateTime(today.year, today.month, today.day - 1);
      await tester.tap(find.text('Gasto'));
      await tester.pumpAndSettle();
      await tester.enterText(moneyInput(), '80');
      await tester.pumpAndSettle();

      await tester.tap(
        find.descendant(
          of: find.byType(OutflowSheet),
          matching: find.byIcon(Icons.edit_calendar_outlined),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(DatePickerDialog),
          matching: find.byIcon(Icons.edit_outlined),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byType(DatePickerDialog),
          matching: find.byType(TextField),
        ),
        DateFormat('dd/MM/yyyy').format(yesterday),
      );
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(
        find.text('Foi antes ou depois de você informar o saldo (13h)?'),
        findsOneWidget,
      );
      await tester.tap(find.text(side));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Registrar gasto'));
      await tester.pumpAndSettle();
    }

    testWidgets('lançado hoje como depois do saldo, sai da carteira', (
      tester,
    ) async {
      await seedCheckYesterdayAt13();
      await pumpApp(tester);

      await launchYesterday(tester, 'Depois');

      expect(
        find.descendant(
          of: find.byType(WalletCard),
          matching: find.text(formatMoney(420)),
        ),
        findsOneWidget,
      );
    });

    testWidgets('lançado hoje como antes do saldo, já estava descontado', (
      tester,
    ) async {
      await seedCheckYesterdayAt13();
      await pumpApp(tester);

      await launchYesterday(tester, 'Antes');

      expect(
        find.descendant(
          of: find.byType(WalletCard),
          matching: find.text(formatMoney(500)),
        ),
        findsOneWidget,
      );
    });
  });

  testWidgets('informar de novo um dia passado pergunta se substitui', (
    tester,
  ) async {
    await seedSalary();
    final today = DateTime.now();
    final yesterday = DateTime(today.year, today.month, today.day - 1);
    await WalletRepository(database, DataChanges()).saveBalanceCheck(
      BalanceCheck(walletId: 1, amount: 500, checkedAt: endOfDay(yesterday)),
    );
    await pumpApp(tester);

    await tester.tap(find.text('Saldo').first);
    await tester.pumpAndSettle();
    await tester.enterText(moneyInput(), '700');
    await tester.tap(
      find.descendant(
        of: find.byType(BalanceCheckSheet),
        matching: find.byIcon(Icons.edit_calendar_outlined),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(DatePickerDialog),
        matching: find.byIcon(Icons.edit_outlined),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byType(DatePickerDialog),
        matching: find.byType(TextField),
      ),
      DateFormat('dd/MM/yyyy').format(yesterday),
    );
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salvar saldo'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Já existe um saldo informado em '
        '${DateFormat('dd/MM').format(yesterday)} (${formatMoney(500)}). '
        'Substituir?',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Substituir'));
    await tester.pumpAndSettle();

    final checks = await WalletRepository(
      database,
      DataChanges(),
    ).fetchBalanceChecks();
    expect(checks.single.amount, 700);
  });

  testWidgets('excluir a carteira diz o que vai junto', (tester) async {
    await seedSalary();
    final repository = WalletRepository(database, DataChanges());
    await repository.saveOutflow(
      Outflow(
        walletId: 1,
        description: 'Mercado',
        amount: 30,
        spentAt: DateTime.now(),
      ),
    );
    await repository.saveOutflow(
      Outflow(
        walletId: 1,
        description: 'Farmácia',
        amount: 20,
        spentAt: DateTime.now(),
      ),
    );
    await repository.saveBalanceCheck(
      BalanceCheck(walletId: 1, amount: 500, checkedAt: DateTime.now()),
    );
    await pumpApp(tester);

    await tester.tap(
      find.descendant(
        of: find.byType(WalletCard),
        matching: find.text('Salário'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Excluir carteira'));
    await tester.pumpAndSettle();

    expect(
      find.text('2 gastos e 1 saldo informado serão apagados.'),
      findsOneWidget,
    );
  });

  testWidgets('remove o saldo informado pela movimentação', (tester) async {
    await seedSalary();
    await pumpApp(tester);

    await tester.tap(find.text('Saldo').first);
    await tester.pumpAndSettle();
    await tester.enterText(moneyInput(), '-120');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salvar saldo'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Saldo informado'));
    await tester.pumpAndSettle();
    expect(find.byType(BalanceCheckSheet), findsOneWidget);

    await tester.tap(find.text('Remover'));
    await tester.pumpAndSettle();

    expect(find.text('Saldo informado'), findsNothing);
    expect(
      await WalletRepository(database, DataChanges()).fetchBalanceChecks(),
      isEmpty,
    );
  });

  testWidgets('lança um gasto avulso pelo cartão da carteira', (tester) async {
    await seedSalary();
    await pumpApp(tester);

    await tester.tap(find.text('Gasto'));
    await tester.pumpAndSettle();

    expect(find.byType(OutflowSheet), findsOneWidget);
    expect(find.text('Gasto em Salário'), findsOneWidget);

    await tester.enterText(
      find.descendant(
        of: find.byType(MoneyField),
        matching: find.byType(TextField),
      ),
      '47,90',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'No que foi'),
      'Mercado',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Registrar gasto'));
    await tester.pumpAndSettle();

    expect(find.text('Mercado'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(WalletCard),
        matching: find.textContaining('47,90'),
      ),
      findsNWidgets(2),
    );
  });

  testWidgets('o gasto lançado num mês passado fica naquele mês', (
    tester,
  ) async {
    await seedSalary();
    await pumpApp(tester);

    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gasto'));
    await tester.pumpAndSettle();
    expect(find.byType(OutflowSheet), findsOneWidget);

    await tester.enterText(
      find.descendant(
        of: find.byType(MoneyField),
        matching: find.byType(TextField),
      ),
      '47,90',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Registrar gasto'));
    await tester.pumpAndSettle();

    final outflow = (await WalletRepository(
      database,
      DataChanges(),
    ).fetchOutflows()).single;
    expect(outflow.month, Month.current().previous);
  });

  testWidgets('corrige um gasto avulso já lançado', (tester) async {
    await seedSalary();
    await pumpApp(tester);

    await tester.tap(find.text('Gasto'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byType(MoneyField),
        matching: find.byType(TextField),
      ),
      '47,90',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'No que foi'),
      'Mercado',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Registrar gasto'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Mercado'));
    await tester.pumpAndSettle();

    expect(find.text('Salvar gasto'), findsOneWidget);

    await tester.tap(find.text('Remover'));
    await tester.pumpAndSettle();

    expect(find.text('Mercado'), findsNothing);
    expect(find.textContaining('3.000,00'), findsWidgets);
  });

  testWidgets('muda o salário para o quinto dia útil', (tester) async {
    await seedSalary();
    await pumpApp(tester);

    await tester.tap(
      find.descendant(
        of: find.byType(WalletCard),
        matching: find.text('Salário'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Mensal'));
    await tester.pumpAndSettle();

    expect(find.byType(PayoutEditorSheet), findsOneWidget);
    expect(find.text('Editar recebimento'), findsOneWidget);

    await tester.tap(find.text('Dia útil'));
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: find.byType(DayOfMonthPicker),
        matching: find.text('5'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Cai no 5º dia útil'), findsOneWidget);

    await tester.tap(find.text('Salvar recebimento'));
    await tester.pumpAndSettle();

    expect(find.textContaining('5º dia útil'), findsWidgets);

    await tester.tap(find.text('Salvar alterações'));
    await tester.pumpAndSettle();

    expect(find.textContaining('5º dia útil'), findsWidgets);
  });

  testWidgets('o recebimento por dia útil pode contar o sábado', (
    tester,
  ) async {
    await seedSalary(schedule: PayoutSchedule.businessDay);
    await pumpApp(tester);

    await tester.tap(
      find.descendant(
        of: find.byType(WalletCard),
        matching: find.text('Salário'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mensal'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Contar sábado (prazo da CLT)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salvar recebimento'));
    await tester.pumpAndSettle();

    expect(find.textContaining('(conta sábado)'), findsWidgets);
  });

  group('calendário da entrada e do gasto num mês distante', () {
    final wallet = Wallet(
      id: 1,
      name: 'Salário',
      kind: WalletKind.salary,
      colorIndex: 0,
      createdAt: DateTime(2026),
    );
    final farMonth = Month(DateTime.now().year + 8, 3);

    Future<void> openSheet(
      WidgetTester tester,
      Future<void> Function(BuildContext context) show,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => show(context),
                child: const Text('Abrir'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.edit_calendar_outlined));
      await tester.pumpAndSettle();
    }

    testWidgets('a entrada num mês futuro abre o calendário em hoje', (
      tester,
    ) async {
      await openSheet(
        tester,
        (context) =>
            ReceiptSheet.show(context, wallet: wallet, month: farMonth),
      );

      final picker = tester.widget<DatePickerDialog>(
        find.byType(DatePickerDialog),
      );
      expect(picker.lastDate, DateUtils.dateOnly(DateTime.now()));
      expect(picker.initialDate, DateUtils.dateOnly(DateTime.now()));
    });

    testWidgets('o gasto abre o calendário no mês da tela', (tester) async {
      await openSheet(
        tester,
        (context) =>
            OutflowSheet.show(context, wallet: wallet, month: farMonth),
      );

      expect(find.byType(DatePickerDialog), findsOneWidget);
    });
  });
}
