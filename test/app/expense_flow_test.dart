import 'package:anchor/app/anchor_app.dart';
import 'package:anchor/core/database/app_database.dart';
import 'package:anchor/core/state/data_changes.dart';
import 'package:anchor/core/utils/month.dart';
import 'package:anchor/features/expenses/models/expense.dart';
import 'package:anchor/features/expenses/repositories/expense_repository.dart';
import 'package:anchor/features/expenses/views/widgets/expense_ledger_sheet.dart';
import 'package:anchor/features/expenses/views/widgets/month_table.dart';
import 'package:anchor/features/wallets/models/payout.dart';
import 'package:anchor/features/wallets/models/wallet.dart';
import 'package:anchor/features/wallets/models/wallet_kind.dart';
import 'package:anchor/features/wallets/repositories/wallet_repository.dart';
import 'package:anchor/core/widgets/day_of_month_picker.dart';
import 'package:anchor/core/widgets/money_field.dart';
import 'package:anchor/features/expenses/models/expense_type.dart';
import 'package:anchor/features/settings/viewmodels/settings_view_model.dart';
import 'package:anchor/features/wallets/views/widgets/payout_editor_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/test_database.dart';

void main() {
  late AppDatabase database;

  setUpAll(() => initializeDateFormatting('pt_BR'));

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
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
    await tester.pumpWidget(AnchorApp(settings: settings, database: database));
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
    await tester.pumpWidget(AnchorApp(settings: settings, database: database));
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

    await _addLedgerPayment(tester, wallet: 'Vale mercado', digits: '40000');
    expect(_inSheet('Falta'), findsOneWidget);
    expect(_inSheet('200,00'), findsWidgets);

    await _addLedgerPayment(tester, wallet: 'Salário', digits: '20000');

    expect(_inSheet('Quitada'), findsOneWidget);
    expect(_inSheet('Falta'), findsNothing);
    expect(find.text('Desfazer pagamentos'), findsOneWidget);

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(find.text('Paga'), findsOneWidget);
  });

  testWidgets('edita o valor do mês pela tabela', (tester) async {
    tester.view.physicalSize = const Size(1080, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await _seedMarketExpense(database);

    final settings = SettingsViewModel();
    await settings.initialize();
    await tester.pumpWidget(AnchorApp(settings: settings, database: database));
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
      '14320',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.textContaining('143,20'), findsWidgets);
    expect(find.textContaining('600,00'), findsNothing);
  });
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
    Payout(walletId: salaryId, label: 'Mensal', amount: 3000, day: 1),
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
    Payout(walletId: voucherId, label: 'Mensal', amount: 600, day: 1),
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

Finder _inSheet(String text) => find.descendant(
  of: find.byType(ExpenseLedgerSheet),
  matching: find.textContaining(text),
);

Future<void> _addLedgerPayment(
  WidgetTester tester, {
  required String wallet,
  required String digits,
}) async {
  await tester.tap(find.text('Adicionar pagamento'));
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
    digits,
  );
  await tester.pumpAndSettle();

  await tester.tap(find.text('Lançar'));
  await tester.pumpAndSettle();
}

Future<void> _createSalaryWallet(WidgetTester tester) async {
  await tester.tap(find.text('Cadastrar meu salário'));
  await tester.pumpAndSettle();

  await tester.enterText(find.byType(TextFormField), 'Salário');
  await tester.pumpAndSettle();

  await tester.tap(find.byTooltip('Adicionar data'));
  await tester.pumpAndSettle();

  await tester.enterText(
    find.descendant(
      of: find.byType(PayoutEditorSheet),
      matching: find.widgetWithText(TextField, 'Descrição'),
    ),
    'Mensal',
  );
  await _typeMoney(tester, '300000');
  await tester.tap(_dayCell(1));
  await tester.pumpAndSettle();

  await tester.tap(find.text('Adicionar ao calendário'));
  await tester.pumpAndSettle();

  expect(find.text('Mensal'), findsOneWidget);
  expect(find.textContaining('3.000,00'), findsWidgets);

  await tester.tap(find.text('Criar carteira'));
  await tester.pumpAndSettle();

  expect(find.text('Anchor'), findsOneWidget);
  expect(find.textContaining('3.000,00'), findsWidgets);
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

  await tester.enterText(find.byType(TextFormField), 'Geladeira');
  await tester.pumpAndSettle();

  await tester.tap(find.byType(DropdownButtonFormField<ExpenseType>));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Parcelada').last);
  await tester.pumpAndSettle();

  await _typeMoney(tester, '25000');

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

  expect(find.textContaining('Faltam 7 parcelas'), findsOneWidget);
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

  await tester.tap(find.text('Quitar com Salário'));
  await tester.pumpAndSettle();

  expect(_inSheet('Quitada'), findsOneWidget);

  await tester.tapAt(const Offset(10, 10));
  await tester.pumpAndSettle();

  expect(find.text('Paga'), findsOneWidget);
  expect(find.text('Pagar'), findsNothing);
}

Future<void> _typeMoney(WidgetTester tester, String digits) async {
  await tester.enterText(
    find.descendant(
      of: find.byType(MoneyField),
      matching: find.byType(TextField),
    ),
    digits,
  );
  await tester.pumpAndSettle();
}

Finder _dayCell(int day) => find.descendant(
  of: find.byType(DayOfMonthPicker),
  matching: find.text('$day'),
);
