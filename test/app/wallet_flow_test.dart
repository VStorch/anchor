import 'package:anchor/app/anchor_app.dart';
import 'package:anchor/core/database/app_database.dart';
import 'package:anchor/core/state/data_changes.dart';
import 'package:anchor/core/widgets/day_of_month_picker.dart';
import 'package:anchor/core/widgets/money_field.dart';
import 'package:anchor/features/dashboard/views/widgets/balance_card.dart';
import 'package:anchor/features/settings/viewmodels/settings_view_model.dart';
import 'package:anchor/features/wallets/models/payout.dart';
import 'package:anchor/features/wallets/models/payout_schedule.dart';
import 'package:anchor/features/wallets/models/wallet.dart';
import 'package:anchor/features/wallets/models/wallet_kind.dart';
import 'package:anchor/features/wallets/repositories/wallet_repository.dart';
import 'package:anchor/features/wallets/views/widgets/balance_adjustment_sheet.dart';
import 'package:anchor/features/wallets/views/widgets/payout_editor_sheet.dart';
import 'package:anchor/features/wallets/views/widgets/wallet_card.dart';
import 'package:anchor/features/wallets/views/widgets/outflow_sheet.dart';
import 'package:anchor/features/wallets/views/widgets/receipt_sheet.dart';
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

  Future<void> seedSalary({PayoutSchedule? schedule}) async {
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
        amount: 3000,
        day: 1,
        schedule: schedule ?? PayoutSchedule.dayOfMonth,
      ),
    );
  }

  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final settings = SettingsViewModel();
    await settings.initialize();

    await tester.pumpWidget(AnchorApp(settings: settings, database: database));
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

  testWidgets('o ajuste de saldo muda a capa sem virar entrada do mês', (
    tester,
  ) async {
    await seedSalary();
    await pumpApp(tester);

    await tester.tap(find.text('Saldo').first);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byType(MoneyField),
        matching: find.byType(TextField),
      ),
      '520000',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ajustar saldo'));
    await tester.pumpAndSettle();

    await goToDashboard(tester);

    final card = find.byType(BalanceCard);

    expect(
      find.descendant(of: card, matching: find.textContaining('5.200,00')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: card, matching: find.textContaining('3.000,00')),
      findsWidgets,
    );
  });

  testWidgets('confirma a entrada prevista com o valor real', (tester) async {
    await seedSalary();
    await pumpApp(tester);

    expect(find.textContaining('a confirmar'), findsWidgets);

    await tester.tap(find.textContaining('a confirmar').last);
    await tester.pumpAndSettle();

    expect(find.byType(ReceiptSheet), findsOneWidget);
    expect(find.text('Confirmar recebimento'), findsOneWidget);

    await tester.enterText(
      find.descendant(
        of: find.byType(MoneyField),
        matching: find.byType(TextField),
      ),
      '312045',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Confirmar recebimento'));
    await tester.pumpAndSettle();

    expect(find.textContaining('3.120,45'), findsWidgets);
    expect(find.textContaining('a confirmar'), findsNothing);
  });

  testWidgets('ajusta o saldo da carteira na mão', (tester) async {
    await seedSalary();
    await pumpApp(tester);

    await tester.tap(find.text('Saldo').first);
    await tester.pumpAndSettle();

    expect(find.byType(BalanceAdjustmentSheet), findsOneWidget);
    expect(find.text('Saldo de Salário'), findsOneWidget);

    await tester.enterText(
      find.descendant(
        of: find.byType(MoneyField),
        matching: find.byType(TextField),
      ),
      '520000',
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('a mais'), findsOneWidget);

    await tester.tap(find.text('Ajustar saldo'));
    await tester.pumpAndSettle();

    expect(find.textContaining('5.200,00'), findsWidgets);
    expect(find.text('Ajuste de saldo'), findsOneWidget);
    expect(find.text('Recebido'), findsWidgets);
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
      '4790',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'No que foi'),
      'Mercado',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Registrar gasto'));
    await tester.pumpAndSettle();

    expect(find.text('Mercado'), findsOneWidget);
    expect(find.textContaining('2.952,10'), findsWidgets);
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
      '4790',
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
}
