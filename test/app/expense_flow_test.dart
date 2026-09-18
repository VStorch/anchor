import 'package:anchor/app/anchor_app.dart';
import 'package:anchor/core/database/app_database.dart';
import 'package:anchor/core/state/data_changes.dart';
import 'package:anchor/core/utils/money.dart';
import 'package:anchor/core/utils/month.dart';
import 'package:anchor/features/expenses/models/expense.dart';
import 'package:anchor/features/expenses/repositories/expense_repository.dart';
import 'package:anchor/features/expenses/viewmodels/expense_form_view_model.dart';
import 'package:anchor/features/expenses/views/widgets/expense_ledger_sheet.dart';
import 'package:anchor/features/expenses/views/widgets/month_table.dart';
import 'package:anchor/features/expenses/views/widgets/pay_sheet.dart';
import 'package:anchor/features/wallets/models/balance_check.dart';
import 'package:anchor/features/wallets/models/payout.dart';
import 'package:anchor/features/wallets/models/wallet.dart';
import 'package:anchor/features/wallets/models/wallet_kind.dart';
import 'package:anchor/features/wallets/repositories/wallet_repository.dart';
import 'package:anchor/core/widgets/day_of_month_picker.dart';
import 'package:anchor/core/widgets/money_field.dart';
import 'package:anchor/core/widgets/month_picker_sheet.dart';
import 'package:anchor/features/expenses/models/expense_payment.dart';
import 'package:anchor/features/expenses/models/expense_type.dart';
import 'package:anchor/features/settings/viewmodels/settings_view_model.dart';
import 'package:anchor/features/wallets/views/widgets/wallet_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

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

  testWidgets('cadastra salário, parcelamento em andamento e pagamento', (
    tester,
  ) async {
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

    await _createSalaryWallet(tester);
    await _createInstallmentExpense(tester);
    await _payFirstExpense(tester);
  });

  testWidgets('divide o pagamento do mercado entre o vale e o salário', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await _seedMarketExpense(database);

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
        matching: find.byIcon(Icons.receipt_long_outlined),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Pagar'));
    await tester.pumpAndSettle();

    expect(find.byType(ExpenseLedgerSheet), findsOneWidget);
    expect(_inSheet('Falta'), findsOneWidget);
    expect(_inSheet('600,00'), findsWidgets);

    await _addLedgerPayment(
      tester,
      wallet: 'Vale mercado',
      amount: '400',
      onlyAPart: true,
    );
    expect(_inSheet('Falta'), findsOneWidget);
    expect(_inSheet('200,00'), findsWidgets);

    await _addLedgerPayment(tester, wallet: 'Salário', amount: '200');

    expect(_inSheet('Quitada'), findsOneWidget);
    expect(_inSheet('Falta'), findsNothing);
    expect(find.text('Desfazer pagamentos'), findsOneWidget);

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(find.text('Paga'), findsOneWidget);
  });

  testWidgets('pagar menos dizendo que a conta foi esse valor já quita', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    await _seedMarketExpense(database);
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
    await _tapTab(tester, Icons.receipt_long_outlined);

    await tester.tap(find.text('Pagar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Outro valor ou data'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byType(MoneyField),
        matching: find.byType(TextField),
      ),
      '587,52',
    );
    await tester.pumpAndSettle();

    expect(
      find.text('A conta deste mês foi ${formatMoney(587.52)}'),
      findsOneWidget,
    );
    expect(
      find.text('Paguei só uma parte (falta ${formatMoney(12.48)})'),
      findsOneWidget,
    );
    await tester.tap(find.text('Lançar'));
    await tester.pumpAndSettle();

    expect(_inSheet('Quitada'), findsOneWidget);
    final months = await database.database.then(
      (db) => db.query('expense_months'),
    );
    expect(months.single['amount'], 587.52);
  });

  Future<void> openExpensesTab(WidgetTester tester) async {
    await _seedMarketExpense(database);
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
        matching: find.byIcon(Icons.receipt_long_outlined),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a conta que vence hoje se destaca na lista e no resumo', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    final today = DateTime.now();
    final changes = DataChanges();
    final expenses = ExpenseRepository(database, changes);
    final hasOverdue = today.day > 1;

    await WalletRepository(database, changes).saveWallet(
      Wallet(
        name: 'Salário',
        kind: WalletKind.salary,
        colorIndex: 0,
        createdAt: DateTime(today.year, today.month),
      ),
    );

    Future<void> bill(String name, double amount, int dueDay) =>
        expenses.saveExpense(
          Expense(
            name: name,
            type: ExpenseType.recurring,
            amount: amount,
            dueDay: dueDay,
            startMonth: Month.current(),
            createdAt: DateTime(today.year, today.month),
          ),
        );

    await bill('Internet', 99.90, today.day);
    if (hasOverdue) await bill('Aluguel', 1100, today.day - 1);

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

    await tester.scrollUntilVisible(
      find.text('A pagar'),
      200,
      scrollable: find.byType(Scrollable).first,
    );

    expect(
      find.textContaining(
        hasOverdue ? '1 em atraso · 1 vence hoje' : '1 vence hoje',
      ),
      findsOneWidget,
    );
    expect(find.text('Vence hoje'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.byIcon(Icons.receipt_long_outlined),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Vence hoje'), findsOneWidget);
    if (hasOverdue) expect(find.text('Atrasada'), findsOneWidget);
  });

  testWidgets('tocar na despesa abre os pagamentos, e excluir fica no menu', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    await openExpensesTab(tester);

    await tester.tap(find.text('Mercado'));
    await tester.pumpAndSettle();
    expect(find.byType(ExpenseLedgerSheet), findsOneWidget);

    await tester.tap(find.byTooltip('Mais opções'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Excluir despesa'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Cancelar'));
    await tester.pumpAndSettle();
    expect(find.byType(ExpenseLedgerSheet), findsOneWidget);

    await tester.tap(find.byTooltip('Mais opções'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Excluir despesa'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Excluir'));
    await tester.pumpAndSettle();

    expect(find.byType(ExpenseLedgerSheet), findsNothing);
    expect(find.text('Mercado'), findsNothing);
  });

  testWidgets('a despesa nova já vem com o salário como fonte', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    await openExpensesTab(tester);

    await tester.tap(find.text('Nova despesa'));
    await tester.pumpAndSettle();

    final dropdown = tester.widget<DropdownButton<PaymentSource>>(
      find.byType(DropdownButton<PaymentSource>),
    );
    final walletId = (await WalletRepository(
      database,
      DataChanges(),
    ).fetchWallets()).firstWhere((wallet) => wallet.name == 'Salário').id;
    expect(dropdown.value?.walletId, walletId);
  });

  testWidgets('edita o valor do mês pela tabela', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);

    await _seedMarketExpense(database);

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
        matching: find.byIcon(Icons.receipt_long_outlined),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Ver como tabela'));
    await tester.pumpAndSettle();

    expect(find.byType(MonthTable), findsOneWidget);
    expect(find.text('Total'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(MonthTable),
        matching: find.textContaining('R\$ '),
      ),
      findsNothing,
      reason: 'o cabeçalho já diz que as colunas estão em reais',
    );
    expect(find.byTooltip('Ver como lista'), findsOneWidget);

    final screenWidth =
        tester.view.physicalSize.width / tester.view.devicePixelRatio;
    expect(
      tester.getRect(find.text('Falta (R\$)')).right,
      lessThanOrEqualTo(screenWidth),
      reason: 'a coluna Falta precisa caber na largura do celular',
    );

    await tester.tap(
      find
          .descendant(
            of: find.byType(MonthTable),
            matching: find.textContaining('600,00'),
          )
          .first,
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.descendant(
        of: find.byType(MonthTable),
        matching: find.byType(TextField),
      ),
      '143,20',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.textContaining('143,20'), findsWidgets);
    expect(find.textContaining('600,00'), findsNothing);
  });

  group('botão de nova despesa e total da tabela', () {
    Future<void> openManyBills(WidgetTester tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final repository = ExpenseRepository(database, DataChanges());
      for (var day = 1; day <= 14; day++) {
        await repository.saveExpense(
          Expense(
            name: 'Conta $day',
            type: ExpenseType.recurring,
            amount: 100.0 * day,
            dueDay: day,
            startMonth: Month.current(),
            createdAt: DateTime(2020),
          ),
        );
      }

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
      await _tapTab(tester, Icons.receipt_long_outlined);
    }

    Finder fab() => find.byWidgetPredicate(
      (widget) =>
          widget is FloatingActionButton && widget.heroTag == 'new-expense',
    );

    bool fabHidden(WidgetTester tester) => tester
        .widget<IgnorePointer>(
          find.ancestor(of: fab(), matching: find.byType(IgnorePointer)).first,
        )
        .ignoring;

    testWidgets('rolar para baixo esconde o botão e rolar para cima o traz', (
      tester,
    ) async {
      await openManyBills(tester);
      expect(fabHidden(tester), isFalse);
      expect(tester.widget<FloatingActionButton>(fab()).isExtended, isTrue);

      final list = find.byType(Scrollable).last;
      await tester.drag(list, const Offset(0, -200));
      await tester.pumpAndSettle();
      expect(fabHidden(tester), isTrue);

      await tester.drag(list, const Offset(0, 80));
      await tester.pumpAndSettle();
      expect(fabHidden(tester), isFalse);
      expect(tester.widget<FloatingActionButton>(fab()).isExtended, isFalse);
    });

    testWidgets('o botão volta quando o mês trocado não tem o que rolar', (
      tester,
    ) async {
      await openManyBills(tester);

      await tester.drag(find.byType(Scrollable).last, const Offset(0, -200));
      await tester.pumpAndSettle();
      expect(fabHidden(tester), isTrue);

      await tester.tap(find.byTooltip('Mês anterior'));
      await tester.pumpAndSettle();

      expect(find.text('Nenhuma despesa cadastrada'), findsNothing);
      expect(fabHidden(tester), isFalse);
      expect(tester.widget<FloatingActionButton>(fab()).isExtended, isTrue);
    });

    testWidgets('o botão volta quando o filtro esvazia a lista', (
      tester,
    ) async {
      await openManyBills(tester);

      await tester.drag(find.byType(Scrollable).last, const Offset(0, -200));
      await tester.pumpAndSettle();
      expect(fabHidden(tester), isTrue);

      await tester.ensureVisible(find.text('Pagas'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pagas'));
      await tester.pumpAndSettle();

      expect(find.text('Nada neste filtro'), findsOneWidget);
      expect(fabHidden(tester), isFalse);
    });

    testWidgets('as células tocáveis da tabela têm 48dp e dizem o que são', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await openManyBills(tester);
      await tester.tap(find.byTooltip('Ver como tabela'));
      await tester.pumpAndSettle();

      for (final label in [
        'Despesa: Conta 1, dia 1',
        'Valor de Conta 1: ${formatMoney(100)}',
        'Pago de Conta 1: nada',
      ]) {
        final cell = find.bySemanticsLabel(label);
        expect(cell, findsOneWidget, reason: label);
        expect(
          tester.getSemantics(cell).rect.height,
          greaterThanOrEqualTo(48),
          reason: label,
        );
      }
      semantics.dispose();
    });

    testWidgets(
      'a tabela rola inteira com os títulos presos e o total alinhado',
      (tester) async {
        await openManyBills(tester);
        await tester.tap(find.byTooltip('Ver como tabela'));
        await tester.pumpAndSettle();
        expect(tester.widget<FloatingActionButton>(fab()).isExtended, isFalse);

        final table = find.byType(MonthTable);
        final rows = find
            .descendant(of: table, matching: find.byType(Scrollable))
            .last;
        final header = find.text('Pago (R\$)');
        final headerTop = tester.getRect(header).top;

        await tester.scrollUntilVisible(
          find.text('Conta 14'),
          200,
          scrollable: rows,
        );
        await tester.drag(rows, const Offset(0, -400));
        await tester.pumpAndSettle();

        expect(
          tester.getRect(find.text('Total')).top,
          greaterThan(tester.getRect(find.text('Conta 14')).bottom),
          reason: 'o total vem depois da última linha, na mesma rolagem',
        );
        expect(tester.getRect(header).top, headerTop, reason: 'título preso');
        expect(
          tester.getRect(find.text('Total')).bottom,
          lessThanOrEqualTo(tester.getRect(find.byType(NavigationBar)).top),
        );

        final paidTotal = find.descendant(
          of: find.ancestor(
            of: find.text('Total'),
            matching: find.byType(Table),
          ),
          matching: find.text(formatAmount(0)),
        );
        expect(
          tester.getRect(paidTotal).right,
          closeTo(tester.getRect(header).right, 1),
          reason: 'o total do Pago fica na coluna do Pago',
        );
      },
    );
  });

  testWidgets('a parcelada só mostra o plano depois de um total válido', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
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
    await _tapTab(tester, Icons.receipt_long_outlined);
    await tester.tap(find.text('Cadastrar despesa'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<ExpenseType>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Parcelada').last);
    await tester.pumpAndSettle();

    expect(find.text('Parcelas já pagas'), findsNothing);
    expect(find.byType(Scrollable).last, findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Escolha o dia do vencimento'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Ainda falta pagar'), findsNothing);
    await tester.scrollUntilVisible(
      find.widgetWithText(TextFormField, 'Total de parcelas'),
      -200,
      scrollable: find.byType(Scrollable).last,
    );

    final total = find.widgetWithText(TextFormField, 'Total de parcelas');
    await tester.enterText(total, '1');
    await tester.pumpAndSettle();
    expect(find.text('De 2 a 480 parcelas'), findsOneWidget);
    expect(
      find.descendant(of: total, matching: find.text('1')),
      findsOneWidget,
      reason: 'o campo mostra o que foi digitado',
    );
    final button = find.text('Total de parcelas: de 2 a 480 parcelas');
    await tester.scrollUntilVisible(
      button,
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(button, findsOneWidget);
    await tester.scrollUntilVisible(
      total,
      -200,
      scrollable: find.byType(Scrollable).last,
    );

    await tester.enterText(total, '10');
    await tester.pumpAndSettle();
    expect(find.text('Parcelas já pagas'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Ainda falta pagar'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Ainda falta pagar'), findsOneWidget);
  });

  testWidgets('tocar na célula da tabela e sair sem editar não fixa o mês', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);

    await _seedMarketExpense(database);

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
        matching: find.byIcon(Icons.receipt_long_outlined),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Ver como tabela'));
    await tester.pumpAndSettle();

    Finder amountCell() => find
        .descendant(
          of: find.byType(MonthTable),
          matching: find.textContaining('600,00'),
        )
        .first;
    final cellField = find.descendant(
      of: find.byType(MonthTable),
      matching: find.byType(TextField),
    );

    await tester.tap(amountCell());
    await tester.pumpAndSettle();
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();

    await tester.tap(amountCell());
    await tester.pumpAndSettle();
    await tester.enterText(cellField, '');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    final monthAmounts = await ExpenseRepository(
      database,
      DataChanges(),
    ).fetchMonthAmounts();
    expect(monthAmounts, isEmpty);
    expect(amountCell(), findsOneWidget);
    expect(find.text('Quitada'), findsNothing);
  });

  testWidgets('o pagamento de despesa sem carteira sai de alguma carteira', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);

    await _seedWalletlessExpense(database);

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
        matching: find.byIcon(Icons.receipt_long_outlined),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Ver como tabela'));
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(of: find.byType(MonthTable), matching: find.text('—')),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.descendant(
        of: find.byType(MonthTable),
        matching: find.byType(TextField),
      ),
      '100',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.byIcon(Icons.account_balance_wallet_outlined),
      ),
    );
    await tester.pumpAndSettle();

    final card = find.byType(WalletCard);

    expect(
      find.descendant(
        of: card,
        matching: find.textContaining('saiu ${formatMoney(100)}'),
      ),
      findsOneWidget,
      reason: 'o gasto precisa aparecer na carteira',
    );
    expect(
      find.descendant(of: card, matching: find.textContaining('2.900,00')),
      findsOneWidget,
    );
  });

  group('pagar com data e com outro dinheiro', () {
    final previousMonth = Month.current().previous;

    Future<void> openWithCheck(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.625;
      addTearDown(tester.view.reset);

      await _seedRentAndGymWithCheck(database, since: previousMonth);
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
      await _tapTab(tester, Icons.receipt_long_outlined);
    }

    Future<void> expectWalletBalance(WidgetTester tester, double amount) async {
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      await _tapTab(tester, Icons.account_balance_wallet_outlined);
      expect(
        find.descendant(
          of: find.byType(WalletCard),
          matching: find.text(formatMoney(amount)),
        ),
        findsOneWidget,
      );
    }

    testWidgets(
      'a conta vencida antes do saldo informado já estava descontada',
      (tester) async {
        await openWithCheck(tester);
        await tester.tap(find.byIcon(Icons.chevron_left));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Aluguel'));
        await tester.pumpAndSettle();
        expect(_inSheet('Sai de Salário'), findsOneWidget);

        await tester.tap(find.text('Marcar como paga'));
        await tester.pumpAndSettle();
        expect(find.textContaining('O valor já tinha saído?'), findsOneWidget);

        await tester.tap(find.text('Sim, já estava descontado'));
        await tester.pumpAndSettle();

        expect(_inSheet('Quitada'), findsOneWidget);
        await expectWalletBalance(tester, 850);
      },
    );

    testWidgets('a folha de pagamento pergunta antes de lançar', (
      tester,
    ) async {
      await openWithCheck(tester);
      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Aluguel'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Outro valor ou data'));
      await tester.pumpAndSettle();

      final sheet = find.byType(PaySheet);
      expect(
        find.descendant(
          of: sheet,
          matching: find.textContaining('O valor já tinha saído?'),
        ),
        findsOneWidget,
      );
      final launch = find.widgetWithText(FilledButton, 'Lançar');
      expect(tester.widget<FilledButton>(launch).onPressed, isNull);

      await tester.tap(find.text('Sim, já estava descontado'));
      await tester.pumpAndSettle();
      await tester.tap(launch);
      await tester.pumpAndSettle();

      expect(_inSheet('Quitada'), findsOneWidget);
      await expectWalletBalance(tester, 850);
    });

    testWidgets('a célula Pago da tabela pergunta no primeiro pagamento', (
      tester,
    ) async {
      await openWithCheck(tester);
      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Ver como tabela'));
      await tester.pumpAndSettle();

      await tester.tap(
        find.descendant(of: find.byType(MonthTable), matching: find.text('—')),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byType(MonthTable),
          matching: find.byType(TextField),
        ),
        '1100',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(find.textContaining('O valor já tinha saído?'), findsOneWidget);
      await tester.tap(find.text('Sim, já estava descontado'));
      await tester.pumpAndSettle();

      final payment = (await ExpenseRepository(
        database,
        DataChanges(),
      ).fetchPayments()).single;
      expect(payment.amount, 1100);
      expect(
        payment.paidAt,
        DateTime(previousMonth.year, previousMonth.month, 10, 12),
      );
      await expectWalletBalance(tester, 850);
    });

    testWidgets('pagar no dia do saldo informado pergunta de que lado', (
      tester,
    ) async {
      await openWithCheck(tester);

      await tester.tap(find.text('Academia'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Outro valor ou data'));
      await tester.pumpAndSettle();

      final sheet = find.byType(PaySheet);
      await tester.tap(
        find.descendant(
          of: sheet,
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
        DateFormat('dd/MM/yyyy').format(DateTime.now()),
      );
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: sheet,
          matching: find.textContaining('O valor já tinha saído?'),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: sheet,
          matching: find.textContaining('Foi antes ou depois de você informar'),
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Antes'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lançar'));
      await tester.pumpAndSettle();

      expect(_inSheet('Quitada'), findsOneWidget);
      await expectWalletBalance(tester, 850);
    });

    testWidgets('paga com uma data passada escolhida no calendário', (
      tester,
    ) async {
      await openWithCheck(tester);
      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Aluguel'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Outro valor ou data'));
      await tester.pumpAndSettle();

      final sheet = find.byType(PaySheet);
      await tester.tap(
        find.descendant(
          of: sheet,
          matching: find.byIcon(Icons.edit_calendar_outlined),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(CalendarDatePicker),
          matching: find.text('5'),
        ),
      );
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      final day = previousMonth.dayOf(5);
      expect(
        find.descendant(
          of: sheet,
          matching: find.textContaining(DateFormat.yMMMMd('pt_BR').format(day)),
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('Lançar'));
      await tester.pumpAndSettle();

      expect(_inSheet('Quitada'), findsOneWidget);
      expect(_inSheet(DateFormat.yMMMd('pt_BR').format(day)), findsOneWidget);
      final payment = (await ExpenseRepository(
        database,
        DataChanges(),
      ).fetchPayments()).single;
      expect(payment.paidAt, DateTime(day.year, day.month, day.day, 12));
      await expectWalletBalance(tester, 850);
    });

    testWidgets('outro dinheiro quita a conta sem mexer no saldo', (
      tester,
    ) async {
      await openWithCheck(tester);

      await tester.tap(find.text('Academia'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Outro valor ou data'));
      await tester.pumpAndSettle();

      await tester.tap(
        find.descendant(
          of: find.byType(ChoiceChip),
          matching: find.text('Outro dinheiro'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Não mexe no saldo'), findsOneWidget);

      await tester.tap(find.text('Lançar'));
      await tester.pumpAndSettle();

      expect(_inSheet('Quitada'), findsOneWidget);
      expect(_inSheet('Outro dinheiro'), findsOneWidget);
      final payment = (await ExpenseRepository(
        database,
        DataChanges(),
      ).fetchPayments()).single;
      expect(payment.settledOutside, isTrue);
      await expectWalletBalance(tester, 850);
    });
  });

  group('mudar a regra da despesa', () {
    Future<void> openExpenses(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.625;
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
          matching: find.byIcon(Icons.receipt_long_outlined),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> editExpense(WidgetTester tester, String name) async {
      await tester.tap(find.text(name));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Mais opções'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Editar despesa'));
      await tester.pumpAndSettle();
    }

    testWidgets('excluir com pagamentos avisa e oferece encerrar', (
      tester,
    ) async {
      final month = Month.current();
      await _seedGym(
        database,
        startMonth: month.previous,
        paidMonths: [month.previous],
      );
      await openExpenses(tester);

      await tester.tap(find.text('Academia'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Mais opções'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Excluir despesa'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Excluir apaga também 1 pagamento'),
        findsOneWidget,
      );
      expect(find.widgetWithText(TextButton, 'Excluir tudo'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Encerrar neste mês'));
      await tester.pumpAndSettle();

      final repository = ExpenseRepository(database, DataChanges());
      expect((await repository.fetchExpenses()).single.endMonth, month);
      expect(await repository.fetchPayments(), hasLength(1));
    });

    testWidgets('a recorrente com início depois do fim não salva', (
      tester,
    ) async {
      final month = Month.current();
      await _seedGym(database, startMonth: month, endMonth: month);
      await openExpenses(tester);
      await editExpense(tester, 'Academia');

      expect(find.text(month.label), findsNWidgets(2));
      await tester.tap(find.byIcon(Icons.calendar_month_outlined));
      await tester.pumpAndSettle();
      await _pickMonth(tester, from: month, target: month.next);

      expect(find.text('Termina antes de começar'), findsOneWidget);
      final save = find.widgetWithText(FilledButton, 'Salvar alterações');
      await tester.scrollUntilVisible(
        save,
        200,
        scrollable: find.byType(Scrollable).last,
      );
      expect(tester.widget<FilledButton>(save).onPressed, isNull);

      final saved = (await ExpenseRepository(
        database,
        DataChanges(),
      ).fetchExpenses()).single;
      expect(saved.startMonth, month);
    });

    testWidgets('encerrar antes de um mês pago mantém o item e o que saiu', (
      tester,
    ) async {
      final month = Month.current();
      await _seedGym(database, startMonth: month.previous, paidMonths: [month]);
      await openExpenses(tester);
      await editExpense(tester, 'Academia');

      await tester.tap(find.text('Termina em'));
      await tester.pumpAndSettle();
      await _pickMonth(tester, from: month.previous, target: month.previous);
      expect(find.text(month.previous.label), findsWidgets);

      final save = find.widgetWithText(FilledButton, 'Salvar alterações');
      await tester.scrollUntilVisible(
        save,
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(save);
      await tester.pumpAndSettle();

      expect(
        find.text(
          '1 mês já pago fica fora da nova regra e continua no histórico.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(TextButton, 'Salvar'));
      await tester.pumpAndSettle();

      final repository = ExpenseRepository(database, DataChanges());
      expect(
        (await repository.fetchExpenses()).single.endMonth,
        month.previous,
      );
      expect(await repository.fetchPayments(), hasLength(1));

      expect(find.text('Academia'), findsOneWidget);
      expect(find.textContaining('Fora da regra atual'), findsOneWidget);

      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.byIcon(Icons.pie_chart_outline),
        ),
      );
      await tester.pumpAndSettle();

      final spent = find.ancestor(
        of: find.text('Saiu'),
        matching: find.byType(Column),
      );
      expect(
        find.descendant(
          of: spent.first,
          matching: find.textContaining('120,00'),
        ),
        findsOneWidget,
      );
    });
  });
}

Future<void> _seedWalletlessExpense(AppDatabase database) async {
  final changes = DataChanges();
  final wallets = WalletRepository(database, changes);
  final expenses = ExpenseRepository(database, changes);
  final today = DateTime.now();

  final salaryId = await wallets.saveWallet(
    Wallet(
      name: 'Salário',
      kind: WalletKind.salary,
      colorIndex: 0,
      createdAt: DateTime(today.year, today.month),
    ),
  );
  await wallets.savePayout(
    Payout(
      walletId: salaryId,
      label: '',
      amount: 3000,
      day: 1,
      createdAt: DateTime(today.year, today.month),
    ),
  );
  await confirmDuePayouts(wallets);

  await expenses.saveExpense(
    Expense(
      name: 'Internet',
      type: ExpenseType.recurring,
      amount: 100,
      dueDay: 10,
      startMonth: Month.current(),
      createdAt: DateTime.now(),
    ),
  );
}

Future<void> _seedMarketExpense(AppDatabase database) async {
  final changes = DataChanges();
  final wallets = WalletRepository(database, changes);
  final expenses = ExpenseRepository(database, changes);
  final today = DateTime.now();

  final salaryId = await wallets.saveWallet(
    Wallet(
      name: 'Salário',
      kind: WalletKind.salary,
      colorIndex: 0,
      createdAt: DateTime(today.year, today.month),
    ),
  );
  await wallets.savePayout(
    Payout(
      walletId: salaryId,
      label: '',
      amount: 3000,
      day: 1,
      createdAt: DateTime(today.year, today.month),
    ),
  );

  final voucherId = await wallets.saveWallet(
    Wallet(
      name: 'Vale mercado',
      kind: WalletKind.benefit,
      colorIndex: 1,
      createdAt: DateTime(today.year, today.month),
    ),
  );
  await wallets.savePayout(
    Payout(
      walletId: voucherId,
      label: '',
      amount: 600,
      day: 1,
      createdAt: DateTime(today.year, today.month),
    ),
  );

  await expenses.saveExpense(
    Expense(
      name: 'Mercado',
      type: ExpenseType.recurring,
      amount: 600,
      dueDay: 10,
      startMonth: Month.current(),
      walletId: voucherId,
      createdAt: DateTime.now(),
    ),
  );
}

Future<void> _seedRentAndGymWithCheck(
  AppDatabase database, {
  required Month since,
}) async {
  final changes = DataChanges();
  final wallets = WalletRepository(database, changes);
  final expenses = ExpenseRepository(database, changes);

  final salaryId = await wallets.saveWallet(
    Wallet(
      name: 'Salário',
      kind: WalletKind.salary,
      colorIndex: 0,
      createdAt: since.firstDay,
    ),
  );
  await wallets.saveBalanceCheck(
    BalanceCheck(walletId: salaryId, amount: 850, checkedAt: DateTime.now()),
  );
  await expenses.saveExpense(
    Expense(
      name: 'Aluguel',
      type: ExpenseType.recurring,
      amount: 1100,
      dueDay: 10,
      startMonth: since,
      walletId: salaryId,
      createdAt: since.firstDay,
    ),
  );
  await expenses.saveExpense(
    Expense(
      name: 'Academia',
      type: ExpenseType.single,
      amount: 120,
      dueDay: 10,
      startMonth: Month.current(),
      walletId: salaryId,
      createdAt: DateTime.now(),
    ),
  );
}

Future<void> _tapTab(WidgetTester tester, IconData icon) async {
  await tester.tap(
    find.descendant(
      of: find.byType(NavigationBar),
      matching: find.byIcon(icon),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _inSheet(String text) => find.descendant(
  of: find.byType(ExpenseLedgerSheet),
  matching: find.textContaining(text),
);

Future<void> _addLedgerPayment(
  WidgetTester tester, {
  required String wallet,
  required String amount,
  bool onlyAPart = false,
}) async {
  await tester.tap(find.text('Outro valor ou data'));
  await tester.pumpAndSettle();

  await tester.tap(
    find.descendant(of: find.byType(ChoiceChip), matching: find.text(wallet)),
  );
  await tester.pumpAndSettle();

  await tester.enterText(
    find.descendant(
      of: find.byType(MoneyField),
      matching: find.byType(TextField),
    ),
    amount,
  );
  await tester.pumpAndSettle();

  if (onlyAPart) {
    await tester.tap(find.textContaining('Paguei só uma parte'));
    await tester.pumpAndSettle();
  }
  await tester.tap(find.text('Lançar'));
  await tester.pumpAndSettle();
}

Future<void> _createSalaryWallet(WidgetTester tester) async {
  await tester.tap(find.text('Cadastrar meu salário'));
  await tester.pumpAndSettle();

  await tester.enterText(
    find.widgetWithText(TextFormField, 'Nome da carteira'),
    'Salário',
  );
  await tester.pumpAndSettle();

  await tester.tap(find.byTooltip('Adicionar data'));
  await tester.pumpAndSettle();

  await _typeMoney(tester, '3000');
  expect(find.text('Em que dia cai?'), findsOneWidget);
  expect(find.text('Escolha o dia'), findsOneWidget);
  await tester.tap(_dayCell(1));
  await tester.pumpAndSettle();

  await tester.tap(find.text('Adicionar ao calendário'));
  await tester.pumpAndSettle();

  expect(find.textContaining('3.000,00 · dia 1'), findsOneWidget);
  expect(find.textContaining('próximo: '), findsOneWidget);

  await tester.tap(find.text('Criar carteira'));
  await tester.pumpAndSettle();

  expect(find.text('Anchor'), findsOneWidget);
  expect(find.text('Salário'), findsWidgets);
}

Future<void> _createInstallmentExpense(WidgetTester tester) async {
  await tester.tap(
    find.descendant(
      of: find.byType(NavigationBar),
      matching: find.byIcon(Icons.receipt_long_outlined),
    ),
  );
  await tester.pumpAndSettle();

  await tester.tap(find.text('Nova despesa'));
  await tester.pumpAndSettle();

  await tester.enterText(
    find.widgetWithText(TextFormField, 'Nome da despesa'),
    'Geladeira',
  );
  await tester.pumpAndSettle();

  await tester.tap(find.byType(DropdownButtonFormField<ExpenseType>));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Parcelada').last);
  await tester.pumpAndSettle();

  await _typeMoney(tester, '250');

  await tester.enterText(
    find.widgetWithText(TextFormField, 'Total de parcelas'),
    '12',
  );
  await tester.pumpAndSettle();

  final settledStepper = find.ancestor(
    of: find.text('Parcelas já pagas'),
    matching: find.byType(Container),
  );
  for (var tap = 0; tap < 5; tap++) {
    await tester.tap(
      find.descendant(
        of: settledStepper.first,
        matching: find.byIcon(Icons.add_circle_outline),
      ),
    );
    await tester.pumpAndSettle();
  }

  final save = find.text('Escolha o dia do vencimento');
  await tester.ensureVisible(save);
  expect(
    tester
        .widget<FilledButton>(
          find.ancestor(of: save, matching: find.byType(FilledButton)),
        )
        .onPressed,
    isNull,
  );
  await tester.ensureVisible(_dayCell(20));
  await tester.tap(_dayCell(20));
  await tester.pumpAndSettle();

  expect(find.textContaining('Faltam 7 parcelas'), findsOneWidget);
  expect(
    find.text('${Month.current().label} será a parcela 6 de 12'),
    findsOneWidget,
  );
  expect(find.textContaining('1.750,00'), findsOneWidget);

  await tester.tap(find.text('Cadastrar despesa'));
  await tester.pumpAndSettle();

  expect(find.text('Geladeira'), findsOneWidget);
  expect(find.textContaining('Parcela 6 de 12'), findsOneWidget);
}

Future<void> _payFirstExpense(WidgetTester tester) async {
  await tester.tap(find.text('Pagar'));
  await tester.pumpAndSettle();

  expect(find.byType(ExpenseLedgerSheet), findsOneWidget);

  await tester.tap(find.text('Marcar como paga'));
  await tester.pumpAndSettle();

  expect(_inSheet('Quitada'), findsOneWidget);

  await tester.tapAt(const Offset(10, 10));
  await tester.pumpAndSettle();

  expect(find.text('Paga'), findsOneWidget);
  expect(find.text('Pagar'), findsNothing);
}

/// A sheet opens over the form, so its field is the last one built.
Future<void> _typeMoney(WidgetTester tester, String amount) async {
  await tester.enterText(
    find
        .descendant(
          of: find.byType(MoneyField),
          matching: find.byType(TextField),
        )
        .last,
    amount,
  );
  await tester.pumpAndSettle();
}

Finder _dayCell(int day) => find.descendant(
  of: find.byType(DayOfMonthPicker),
  matching: find.text('$day'),
);

Future<void> _seedGym(
  AppDatabase database, {
  required Month startMonth,
  Month? endMonth,
  List<Month> paidMonths = const <Month>[],
}) async {
  final changes = DataChanges();
  final wallets = WalletRepository(database, changes);
  final expenses = ExpenseRepository(database, changes);
  final createdAt = startMonth.firstDay;

  final salaryId = await wallets.saveWallet(
    Wallet(
      name: 'Salário',
      kind: WalletKind.salary,
      colorIndex: 0,
      createdAt: createdAt,
    ),
  );
  await expenses.saveExpense(
    Expense(
      name: 'Academia',
      type: ExpenseType.recurring,
      amount: 120,
      dueDay: 10,
      startMonth: startMonth,
      endMonth: endMonth,
      walletId: salaryId,
      createdAt: createdAt,
    ),
  );
  final expenseId = (await expenses.fetchExpenses()).single.id!;
  for (final month in paidMonths) {
    await expenses.savePayment(
      ExpensePayment(
        expenseId: expenseId,
        walletId: salaryId,
        month: month,
        amount: 120,
        paidAt: month.dayOf(10),
      ),
    );
  }
}

Future<void> _pickMonth(
  WidgetTester tester, {
  required Month from,
  required Month target,
}) async {
  final sheet = find.byType(MonthPickerSheet);
  for (var year = from.year; year != target.year;) {
    final forward = target.year > year;
    await tester.tap(
      find.descendant(
        of: sheet,
        matching: find.byIcon(
          forward ? Icons.chevron_right : Icons.chevron_left,
        ),
      ),
    );
    await tester.pumpAndSettle();
    year += forward ? 1 : -1;
  }
  await tester.tap(
    find.descendant(
      of: sheet,
      matching: find.text(
        toBeginningOfSentenceCase(
          DateFormat.MMMM('pt_BR').format(target.firstDay),
        )!,
      ),
    ),
  );
  await tester.pumpAndSettle();
}
