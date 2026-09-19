import 'package:anchor/app/anchor_app.dart';
import 'package:anchor/core/database/app_database.dart';
import 'package:anchor/core/state/data_changes.dart';
import 'package:anchor/core/utils/month.dart';
import 'package:anchor/core/widgets/money_field.dart';
import 'package:anchor/features/cards/models/credit_card.dart';
import 'package:anchor/features/cards/repositories/card_repository.dart';
import 'package:anchor/features/cards/views/card_invoice_sheet.dart';
import 'package:anchor/features/expenses/models/expense.dart';
import 'package:anchor/features/expenses/models/expense_type.dart';
import 'package:anchor/features/expenses/repositories/expense_repository.dart';
import 'package:anchor/features/expenses/viewmodels/expense_form_view_model.dart';
import 'package:anchor/features/expenses/views/expense_form_page.dart';
import 'package:anchor/features/expenses/views/widgets/expense_ledger_sheet.dart';
import 'package:anchor/features/settings/viewmodels/settings_view_model.dart';
import 'package:anchor/features/wallets/views/widgets/card_overview_tile.dart';
import 'package:anchor/features/wallets/models/payout.dart';
import 'package:anchor/features/wallets/models/wallet.dart';
import 'package:anchor/features/wallets/models/wallet_kind.dart';
import 'package:anchor/features/wallets/repositories/wallet_repository.dart';
import 'package:anchor/core/widgets/day_of_month_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:anchor/core/utils/money.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import '../support/fake_reminder_notifications.dart';
import '../support/preferences.dart';
import '../support/test_database.dart';

void main() {
  late AppDatabase database;
  final today = DateTime.now();

  setUpAll(() => initializeDateFormatting('pt_BR'));

  setUp(() {
    mockPreferences();
    database = createInMemoryDatabase();
  });

  tearDown(() => database.close());

  Future<void> seed({bool withCard = true}) async {
    final changes = DataChanges();
    final wallets = WalletRepository(database, changes);
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
        label: 'Mensal',
        amount: 3000,
        day: 1,
        createdAt: DateTime(today.year, today.month),
      ),
    );
    if (!withCard) return;

    final cardId = await CardRepository(database, changes).saveCard(
      CreditCard(
        name: 'Nubank',
        closingDay: 20,
        dueDay: 28,
        walletId: salaryId,
        createdAt: today,
      ),
    );
    final expenses = ExpenseRepository(database, changes);
    for (final (name, amount) in [('Geladeira', 300.0), ('Celular', 150.0)]) {
      await expenses.saveExpense(
        Expense(
          name: name,
          type: ExpenseType.installment,
          amount: amount,
          dueDay: 28,
          startMonth: Month.current(),
          totalInstallments: 10,
          walletId: salaryId,
          cardId: cardId,
          createdAt: today,
        ),
      );
    }
  }

  Future<void> pumpApp(WidgetTester tester) async {
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
  }

  Future<void> tapTab(WidgetTester tester, IconData icon) async {
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.byIcon(icon),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Scrolls [target] into view and out of the FAB's corner, so a tap on it
  /// is not swallowed by the button.
  Future<void> bringIntoReach(
    WidgetTester tester,
    Finder target,
    Finder list,
  ) async {
    await tester.scrollUntilVisible(target, 200, scrollable: list);
    await tester.pumpAndSettle();
    final limit = tester.getSize(find.byType(MaterialApp)).height - 120;
    final bottom = tester.getRect(target).bottom;
    if (bottom > limit) {
      await tester.drag(list, Offset(0, limit - bottom));
      await tester.pumpAndSettle();
    }
  }

  Finder inSheet(String text) => find.descendant(
    of: find.byType(CardInvoiceSheet),
    matching: find.textContaining(text),
  );

  testWidgets(
    'as compras do cartão aparecem como uma fatura e se pagam juntas',
    (tester) async {
      await seed();
      await pumpApp(tester);
      await tapTab(tester, Icons.receipt_long_outlined);

      expect(find.text('Fatura Nubank'), findsOneWidget);
      expect(find.text('Geladeira'), findsNothing);
      expect(find.textContaining('2 compras · Salário'), findsOneWidget);

      await tester.tap(find.text('Fatura Nubank'));
      await tester.pumpAndSettle();

      expect(inSheet('Geladeira'), findsOneWidget);
      expect(inSheet('Celular'), findsOneWidget);
      expect(inSheet('Falta R\$'), findsOneWidget);
      expect(inSheet('Sai de Salário'), findsOneWidget);

      await tester.tap(find.text('Marcar fatura como paga'));
      await tester.pumpAndSettle();

      expect(inSheet('Paga · '), findsOneWidget);
      expect(inSheet('450,00'), findsWidgets);

      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(find.text('Paga'), findsOneWidget);
    },
  );

  testWidgets('excluir o cartão pela fatura fecha a folha e solta as compras', (
    tester,
  ) async {
    await seed();
    await pumpApp(tester);
    await tapTab(tester, Icons.receipt_long_outlined);

    await tester.tap(find.text('Fatura Nubank'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Editar cartão'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Excluir cartão'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Excluir'));
    await tester.pumpAndSettle();

    expect(find.byType(CardInvoiceSheet), findsNothing);
    expect(find.text('Fatura Nubank'), findsNothing);
    expect(find.text('Geladeira'), findsOneWidget);
    expect(find.text('Celular'), findsOneWidget);
  });

  testWidgets('escolher o cartão no cadastro tira o dia de vencimento', (
    tester,
  ) async {
    await seed();
    await pumpApp(tester);
    await tapTab(tester, Icons.receipt_long_outlined);

    await tester.tap(find.text('Nova despesa'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nome da despesa'),
      'Tênis',
    );
    await tester.enterText(
      find.descendant(
        of: find.byType(MoneyField),
        matching: find.byType(TextField),
      ),
      '200',
    );
    expect(find.text('Dia do vencimento'), findsOneWidget);

    await tester.tap(find.byType(DropdownButtonFormField<PaymentSource>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nubank').last);
    await tester.pumpAndSettle();

    expect(find.text('Dia do vencimento'), findsNothing);

    expect(find.text('Nova compra no Nubank'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Salvar compra'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Salvar compra'));
    await tester.pumpAndSettle();

    final saved = (await ExpenseRepository(
      database,
      DataChanges(),
    ).fetchExpenses()).firstWhere((expense) => expense.name == 'Tênis');
    final card = (await CardRepository(
      database,
      DataChanges(),
    ).fetchCards()).single;
    expect(saved.cardId, card.id);
    expect(saved.dueDay, 28);
    expect(saved.startMonth, card.invoiceMonthFor(DateTime.now()));
  });

  testWidgets('a aba Carteiras mostra a fatura aberta e abre a compra dela', (
    tester,
  ) async {
    await seed();
    await pumpApp(tester);
    await tapTab(tester, Icons.account_balance_wallet_outlined);

    final tile = find.byType(CardOverviewTile);
    await bringIntoReach(tester, tile, find.byType(Scrollable).first);

    expect(
      find.descendant(
        of: tile,
        matching: find.textContaining('Aberta · fecha'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: tile, matching: find.text(formatMoney(450))),
      findsOneWidget,
    );

    final purchase = find.descendant(of: tile, matching: find.text('Compra'));
    await bringIntoReach(tester, purchase, find.byType(Scrollable).first);
    await tester.tap(purchase);
    await tester.pumpAndSettle();

    expect(find.byType(ExpenseFormPage), findsOneWidget);
    expect(
      find.text(DateFormat.yMMMMd('pt_BR').format(DateUtils.dateOnly(today))),
      findsOneWidget,
    );
    expect(find.textContaining('vai para a fatura de'), findsNothing);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'O que comprou'),
      'Tênis',
    );
    await tester.enterText(
      find.descendant(
        of: find.byType(MoneyField),
        matching: find.byType(TextField),
      ),
      '50',
    );
    await tester.pumpAndSettle();
    expect(find.text('Nova compra no Nubank'), findsOneWidget);
    expect(find.text('À vista'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Salvar compra'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Salvar compra'));
    await tester.pumpAndSettle();

    final saved = (await ExpenseRepository(
      database,
      DataChanges(),
    ).fetchExpenses()).firstWhere((expense) => expense.name == 'Tênis');
    final card = (await CardRepository(
      database,
      DataChanges(),
    ).fetchCards()).single;
    expect(saved.startMonth, card.invoiceMonthFor(today));
    expect(saved.type, ExpenseType.single);
    expect(
      find.descendant(of: tile, matching: find.text(formatMoney(500))),
      findsOneWidget,
    );
  });

  testWidgets('a compra parcelada é digitada pelo preço total', (tester) async {
    await seed();
    await pumpApp(tester);
    await tapTab(tester, Icons.account_balance_wallet_outlined);

    final tile = find.byType(CardOverviewTile);
    final purchase = find.descendant(of: tile, matching: find.text('Compra'));
    await bringIntoReach(tester, purchase, find.byType(Scrollable).first);
    await tester.tap(purchase);
    await tester.pumpAndSettle();

    expect(find.text('O que comprou'), findsOneWidget);
    expect(find.text('Como pagou'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'O que comprou'),
      'Presente',
    );
    await tester.tap(find.byType(DropdownButtonFormField<ExpenseType>));
    await tester.pumpAndSettle();
    expect(find.text('Todo mês'), findsWidgets);
    await tester.tap(find.text('Parcelado').last);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.descendant(
        of: find.widgetWithText(MoneyField, 'Valor total da compra'),
        matching: find.byType(TextField),
      ),
      '1000',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Total de parcelas'),
      '3',
    );
    await tester.pumpAndSettle();
    expect(
      find.text('3x de ${formatMoney(333.33)} (total ${formatMoney(999.99)})'),
      findsOneWidget,
    );

    await tester.scrollUntilVisible(
      find.text('Salvar compra'),
      200,
      scrollable: find
          .descendant(
            of: find.byType(ExpenseFormPage),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.ensureVisible(find.text('Salvar compra'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salvar compra'));
    await tester.pumpAndSettle();

    final saved = (await ExpenseRepository(
      database,
      DataChanges(),
    ).fetchExpenses()).firstWhere((expense) => expense.name == 'Presente');
    expect(saved.type, ExpenseType.installment);
    expect(saved.amount, 333.33);
    expect(saved.totalInstallments, 3);
  });

  testWidgets(
    'a fatura pendente abre o mês dela, e a compra de hoje vai para a '
    'seguinte',
    (tester) async {
      await seed(withCard: false);
      final changes = DataChanges();
      final cardId = await CardRepository(database, changes).saveCard(
        CreditCard(
          name: 'Inter',
          closingDay: 3,
          dueDay: 10,
          walletId: 1,
          createdAt: DateTime(2026, 9),
        ),
      );
      await ExpenseRepository(database, changes).saveExpense(
        Expense(
          name: 'Livro',
          type: ExpenseType.single,
          amount: 80,
          dueDay: 10,
          startMonth: const Month(2026, 9),
          walletId: 1,
          cardId: cardId,
          purchasedAt: DateTime(2026, 9, 1),
          createdAt: DateTime(2026, 9),
        ),
      );
      await pumpApp(tester);
      await tapTab(tester, Icons.account_balance_wallet_outlined);

      final tile = find.byType(CardOverviewTile);
      final pending = find.descendant(
        of: tile,
        matching: find.text('Fatura de setembro · Atrasada'),
      );
      await bringIntoReach(tester, pending, find.byType(Scrollable).first);
      expect(pending, findsOneWidget);
      for (final line in [pending, find.text('Sem compras · fecha 03/10')]) {
        final row = find.ancestor(of: line, matching: find.byType(InkWell));
        expect(tester.getSize(row.first).height, greaterThanOrEqualTo(48));
      }
      expect(
        find.descendant(
          of: tile,
          matching: find.text('Sem compras · fecha 03/10'),
        ),
        findsOneWidget,
      );

      await tester.tap(pending);
      await tester.pumpAndSettle();

      expect(inSheet('Livro'), findsOneWidget);

      await tester.tap(find.text('Livro'));
      await tester.pumpAndSettle();
      expect(find.byType(ExpenseLedgerSheet), findsOneWidget);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Adicionar compra'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'O que comprou'),
        'Tênis',
      );
      await tester.enterText(
        find.descendant(
          of: find.byType(MoneyField),
          matching: find.byType(TextField),
        ),
        '200',
      );

      final purchaseDay = find.text('Data da compra');
      await tester.ensureVisible(purchaseDay);
      await tester.pumpAndSettle();
      await tester.tap(purchaseDay);
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
        '13/09/2026',
      );
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(
        find.text('Compra de 13/09 vai para a fatura de outubro'),
        findsOneWidget,
      );

      final add = find.text('Salvar compra');
      await tester.scrollUntilVisible(
        add,
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(add);
      await tester.pumpAndSettle();

      expect(find.byType(CardInvoiceSheet), findsOneWidget);
      expect(inSheet('Tênis'), findsNothing);

      final saved = (await ExpenseRepository(
        database,
        DataChanges(),
      ).fetchExpenses()).firstWhere((expense) => expense.name == 'Tênis');
      expect(saved.startMonth, const Month(2026, 10));
      expect(saved.purchasedAt, DateTime(2026, 9, 13));
      expect(saved.dueDay, 10);
    },
  );

  testWidgets('cadastra um cartão pela aba Carteiras', (tester) async {
    await seed(withCard: false);
    await pumpApp(tester);
    await tapTab(tester, Icons.account_balance_wallet_outlined);

    await bringIntoReach(
      tester,
      find.text('Adicionar cartão'),
      find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Adicionar cartão'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nome do cartão'),
      'Inter',
    );
    await tester.pumpAndSettle();
    expect(find.text('Escolha o dia do fechamento'), findsOneWidget);
    for (final (index, day) in [(0, '3'), (1, '10')]) {
      final cell = find.descendant(
        of: find.byType(DayOfMonthPicker).at(index),
        matching: find.text(day),
      );
      await tester.ensureVisible(cell);
      await tester.pumpAndSettle();
      await tester.tap(cell);
      await tester.pumpAndSettle();
    }
    await tester.scrollUntilVisible(
      find.text('Criar cartão'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Criar cartão'));
    await tester.pumpAndSettle();

    expect(find.text('Inter'), findsOneWidget);
    final card = (await CardRepository(
      database,
      DataChanges(),
    ).fetchCards()).firstWhere((card) => card.name == 'Inter');
    expect((card.closingDay, card.dueDay), (3, 10));
  });
}
