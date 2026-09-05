import 'package:anchor/app/anchor_app.dart';
import 'package:anchor/core/database/app_database.dart';
import 'package:anchor/core/state/data_changes.dart';
import 'package:anchor/core/widgets/anchor_logo.dart';
import 'package:anchor/core/utils/month.dart';
import 'package:anchor/features/expenses/models/expense.dart';
import 'package:anchor/features/expenses/models/expense_type.dart';
import 'package:anchor/features/expenses/repositories/expense_repository.dart';
import 'package:anchor/features/settings/viewmodels/settings_view_model.dart';
import 'package:anchor/features/wallets/models/payout.dart';
import 'package:anchor/features/wallets/models/wallet.dart';
import 'package:anchor/features/wallets/models/wallet_kind.dart';
import 'package:anchor/features/wallets/repositories/wallet_repository.dart';
import 'package:anchor/features/wallets/views/widgets/wallet_card.dart';
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

  Future<void> pumpApp(WidgetTester tester) async {
    final settings = SettingsViewModel();
    await settings.initialize();

    await tester.pumpWidget(AnchorApp(settings: settings, database: database));
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

  Future<void> seedSalaryAndExpense() async {
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
      Payout(walletId: walletId, label: 'Mensal', amount: 3000, day: 1),
    );
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

    await tester.pumpWidget(AnchorApp(settings: settings, database: database));

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

  testWidgets('a capa mostra o saldo real e o resultado do mês', (
    tester,
  ) async {
    await seedSalaryAndExpense();
    await pumpApp(tester);

    expect(find.text('Saldo total'), findsWidgets);
    expect(find.text('Entrou'), findsOneWidget);
    expect(find.text('Saiu'), findsOneWidget);
    expect(find.text('Sobrou'), findsOneWidget);
    expect(find.textContaining('3.000,00'), findsWidgets);
    expect(find.textContaining('450,00 a pagar em'), findsOneWidget);
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
}
