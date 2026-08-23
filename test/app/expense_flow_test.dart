import 'package:anchor/app/anchor_app.dart';
import 'package:anchor/core/database/app_database.dart';
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

  expect(find.textContaining('Faltam 7 de 12 parcelas'), findsOneWidget);
  expect(find.textContaining('1.750,00'), findsOneWidget);

  await tester.tap(find.text('Cadastrar despesa'));
  await tester.pumpAndSettle();

  expect(find.text('Geladeira'), findsOneWidget);
  expect(find.textContaining('Parcela 6 de 12'), findsOneWidget);
}

Future<void> _payFirstExpense(WidgetTester tester) async {
  await tester.tap(find.text('Pagar'));
  await tester.pumpAndSettle();

  expect(find.text('Pagar Geladeira'), findsOneWidget);

  await tester.tap(find.text('Salário').last);
  await tester.pumpAndSettle();

  await tester.tap(find.text('Confirmar pagamento'));
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
