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
import '../support/test_database.dart';

void main() {
  late AppDatabase database;

  setUpAll(() => initializeDateFormatting('pt_BR'));

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    database = createInMemoryDatabase();
  });

  tearDown(() => database.close());

  Future<void> seed({bool withCard = true}) async {
    final changes = DataChanges();
    final today = DateTime.now();
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
      Payout(walletId: salaryId, label: 'Mensal', amount: 3000, day: 1),
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
      expect(find.text('2 compras · Salário'), findsOneWidget);

      await tester.tap(find.text('Fatura Nubank'));
      await tester.pumpAndSettle();

      expect(inSheet('Geladeira'), findsOneWidget);
      expect(inSheet('Celular'), findsOneWidget);
      expect(inSheet('Falta R\$'), findsOneWidget);

      await tester.tap(find.text('Pagar fatura com Salário'));
      await tester.pumpAndSettle();

      expect(inSheet('Paga'), findsOneWidget);
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

    await tester.scrollUntilVisible(
      find.text('Cadastrar despesa'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Cadastrar despesa'));
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

  testWidgets('cadastra um cartão pela aba Carteiras', (tester) async {
    await seed(withCard: false);
    await pumpApp(tester);
    await tapTab(tester, Icons.account_balance_wallet_outlined);

    await tester.scrollUntilVisible(
      find.byTooltip('Adicionar cartão'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byTooltip('Adicionar cartão'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nome do cartão'),
      'Inter',
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Criar cartão'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Criar cartão'));
    await tester.pumpAndSettle();

    expect(find.text('Inter'), findsOneWidget);
  });
}
