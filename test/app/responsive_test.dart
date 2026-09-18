import 'package:anchor/app/anchor_app.dart';
import 'package:anchor/core/database/app_database.dart';
import 'package:anchor/core/state/data_changes.dart';
import 'package:anchor/core/utils/month.dart';
import 'package:anchor/features/cards/models/credit_card.dart';
import 'package:anchor/features/cards/repositories/card_repository.dart';
import 'package:anchor/features/dashboard/views/widgets/daily_spending_sheet.dart';
import 'package:anchor/features/expenses/models/expense.dart';
import 'package:anchor/features/expenses/models/expense_payment.dart';
import 'package:anchor/features/expenses/models/expense_type.dart';
import 'package:anchor/features/expenses/repositories/expense_repository.dart';
import 'package:anchor/features/expenses/views/expense_form_page.dart';
import 'package:anchor/features/expenses/views/expenses_page.dart';
import 'package:anchor/features/expenses/views/widgets/expense_tile.dart';
import 'package:anchor/features/settings/viewmodels/settings_view_model.dart';
import 'package:anchor/features/wallets/models/payout.dart';
import 'package:anchor/features/wallets/models/wallet.dart';
import 'package:anchor/features/wallets/models/wallet_kind.dart';
import 'package:anchor/features/wallets/repositories/wallet_repository.dart';
import 'package:anchor/features/wallets/views/wallet_detail_page.dart';
import 'package:anchor/features/wallets/views/wallet_form_page.dart';
import 'package:anchor/features/wallets/views/wallets_page.dart';
import 'package:anchor/features/wallets/views/widgets/card_overview_tile.dart';
import 'package:anchor/features/wallets/views/widgets/spending_source_sheet.dart';
import 'package:anchor/features/wallets/views/widgets/wallet_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_reminder_notifications.dart';
import '../support/onboarding_driver.dart';
import '../support/preferences.dart';
import '../support/test_database.dart';

class _Screen {
  const _Screen(this.name, this.width, this.height, this.textScale);

  final String name;
  final double width;
  final double height;
  final double textScale;
}

const List<_Screen> _screens = <_Screen>[
  _Screen('tela estreita', 320, 640, 1),
  _Screen('tela comum', 411, 914, 1),
  _Screen('fonte ampliada', 411, 914, 1.5),
  _Screen('tela estreita com fonte ampliada', 320, 640, 1.3),
];

void main() {
  late AppDatabase database;

  setUpAll(() => initializeDateFormatting('pt_BR'));

  setUp(() {
    mockPreferences();
    database = createInMemoryDatabase();
  });

  tearDown(() => database.close());

  Future<void> seed() async {
    final changes = DataChanges();
    final wallets = WalletRepository(database, changes);
    final expenses = ExpenseRepository(database, changes);
    final today = DateTime.now();
    final createdAt = DateTime(today.year, today.month);

    final salaryId = await wallets.saveWallet(
      Wallet(
        name: 'Salário da empresa',
        kind: WalletKind.salary,
        colorIndex: 0,
        createdAt: createdAt,
      ),
    );
    await wallets.savePayout(
      Payout(
        walletId: salaryId,
        label: 'Mensal',
        amount: 12345.67,
        day: 1,
        createdAt: createdAt,
      ),
    );

    final voucherId = await wallets.saveWallet(
      Wallet(
        name: 'Vale mercado e refeição',
        kind: WalletKind.benefit,
        colorIndex: 1,
        createdAt: createdAt,
      ),
    );
    await wallets.savePayout(
      Payout(
        walletId: voucherId,
        label: 'Mensal',
        amount: 1234.56,
        day: 1,
        createdAt: createdAt,
      ),
    );

    await expenses.saveExpense(
      Expense(
        name: 'Plano de saúde familiar completo',
        type: ExpenseType.recurring,
        amount: 1987.65,
        dueDay: 10,
        startMonth: Month.current(),
        walletId: salaryId,
        createdAt: DateTime.now(),
      ),
    );
    await expenses.saveExpense(
      Expense(
        name: 'Geladeira',
        type: ExpenseType.installment,
        amount: 987.65,
        dueDay: 20,
        startMonth: Month.current(),
        totalInstallments: 12,
        settledInstallments: 5,
        walletId: voucherId,
        createdAt: DateTime.now(),
      ),
    );

    final cardId = await CardRepository(database, changes).saveCard(
      CreditCard(
        name: 'Cartão de crédito do banco',
        closingDay: 3,
        dueDay: 10,
        walletId: salaryId,
        createdAt: createdAt,
      ),
    );
    await expenses.saveExpense(
      Expense(
        name: 'Fone de ouvido sem fio',
        type: ExpenseType.single,
        amount: 1299.9,
        dueDay: 10,
        startMonth: Month.current(),
        walletId: salaryId,
        cardId: cardId,
        purchasedAt: Month.current().previous.dayOf(20),
        createdAt: DateTime.now(),
      ),
    );

    final saved = (await expenses.fetchExpenses())
        .where((expense) => expense.cardId == null)
        .toList();
    await expenses.savePayment(
      ExpensePayment(
        expenseId: saved.first.id!,
        walletId: salaryId,
        month: Month.current(),
        amount: 500,
        paidAt: DateTime.now(),
      ),
    );
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

  for (final screen in _screens) {
    testWidgets('nada estoura em ${screen.name}', (tester) async {
      tester.view.physicalSize = Size(screen.width, screen.height);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = screen.textScale;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await seed();

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

      for (final icon in const <IconData>[
        Icons.receipt_long_outlined,
        Icons.account_balance_wallet_outlined,
        Icons.tune_outlined,
        Icons.pie_chart_outline,
      ]) {
        await tester.tap(
          find.descendant(
            of: find.byType(NavigationBar),
            matching: find.byIcon(icon),
          ),
        );
        await tester.pumpAndSettle();
      }

      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.byIcon(Icons.receipt_long_outlined),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Ver como tabela'));
      await tester.pumpAndSettle();
      expect(find.text('Total'), findsOneWidget);
      await tester.tap(find.byTooltip('Ver como lista'));
      await tester.pumpAndSettle();

      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.byIcon(Icons.account_balance_wallet_outlined),
        ),
      );
      await tester.pumpAndSettle();
      final walletsList = find
          .descendant(
            of: find.byType(WalletsPage),
            matching: find.byType(Scrollable),
          )
          .first;
      final invoice = find.descendant(
        of: find.byType(CardOverviewTile),
        matching: find.textContaining('Atrasada'),
      );
      await bringIntoReach(tester, invoice, walletsList);
      await tester.tap(invoice);
      await tester.pumpAndSettle();
      final addPurchase = find.text('Adicionar compra');
      await tester.ensureVisible(addPurchase);
      await tester.pumpAndSettle();
      await tester.tap(addPurchase);
      await tester.pumpAndSettle();
      expect(find.byType(ExpenseFormPage), findsOneWidget);
      await tester.ensureVisible(find.textContaining('Fatura de'));
      await tester.pumpAndSettle();
      final navigator = tester.state<NavigatorState>(
        find.byType(Navigator).first,
      );
      navigator.pop();
      await tester.pumpAndSettle();
      navigator.pop();
      await tester.pumpAndSettle();

      final walletName = find.descendant(
        of: find.byType(WalletCard),
        matching: find.text('Salário da empresa'),
      );
      await tester.scrollUntilVisible(
        walletName,
        -200,
        scrollable: find
            .descendant(
              of: find.byType(WalletsPage),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      await tester.tap(walletName);
      await tester.pumpAndSettle();
      expect(find.byType(WalletDetailPage), findsOneWidget);
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -300));
      await tester.pumpAndSettle();
      navigator.pop();
      await tester.pumpAndSettle();

      await tester.tap(
        find.byWidgetPredicate(
          (widget) =>
              widget is FloatingActionButton &&
              widget.heroTag == 'new-spending',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(SpendingSourceSheet), findsOneWidget);
      navigator.pop();
      await tester.pumpAndSettle();

      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.byIcon(Icons.pie_chart_outline),
        ),
      );
      await tester.pumpAndSettle();

      final reserve = find.text('Reservar gasto do dia a dia');
      await tester.scrollUntilVisible(
        reserve,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(reserve);
      await tester.pumpAndSettle();
      expect(find.byType(DailySpendingSheet), findsOneWidget);
      navigator.pop();
      await tester.pumpAndSettle();

      final breakdown = find.text('De onde vem esse valor');
      await tester.scrollUntilVisible(
        breakdown,
        -200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(breakdown);
      await tester.pumpAndSettle();
      await tester.tap(breakdown);
      await tester.pumpAndSettle();

      final details = find.text('Como chegamos nisso');
      await tester.scrollUntilVisible(
        details,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(details);
      await tester.pumpAndSettle();
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -300));
      await tester.pumpAndSettle();
    });
  }

  for (final theme in ['light', 'dark']) {
    testWidgets('as abas têm alvos de toque e contraste suficientes ($theme)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(411, 914);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      mockPreferences(<String, Object>{'theme_mode': theme});
      final semantics = tester.ensureSemantics();

      await seed();
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

      await tester.tap(find.text('Reservar gasto do dia a dia'));
      await tester.pumpAndSettle();
      expect(find.byType(DailySpendingSheet), findsOneWidget);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      tester.state<NavigatorState>(find.byType(Navigator).first).pop();
      await tester.pumpAndSettle();

      await tester.tap(find.text('De onde vem esse valor'));
      await tester.pumpAndSettle();

      for (final icon in const <IconData?>[
        null,
        Icons.receipt_long_outlined,
        Icons.account_balance_wallet_outlined,
        Icons.tune_outlined,
      ]) {
        if (icon != null) {
          await tester.tap(
            find.descendant(
              of: find.byType(NavigationBar),
              matching: find.byIcon(icon),
            ),
          );
          await tester.pumpAndSettle();
        }

        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
      }

      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.byIcon(Icons.receipt_long_outlined),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Ver como tabela'));
      await tester.pumpAndSettle();
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      await tester.tap(find.byTooltip('Ver como lista'));
      await tester.pumpAndSettle();

      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.byIcon(Icons.account_balance_wallet_outlined),
        ),
      );
      await tester.pumpAndSettle();

      final walletsList = find
          .descendant(
            of: find.byType(WalletsPage),
            matching: find.byType(Scrollable),
          )
          .first;
      final cardTile = find.byType(CardOverviewTile);
      await tester.scrollUntilVisible(cardTile, 200, scrollable: walletsList);
      await tester.ensureVisible(cardTile);
      await tester.pumpAndSettle();
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await tester.scrollUntilVisible(
        find.descendant(
          of: find.byType(WalletCard),
          matching: find.text('Salário da empresa'),
        ),
        -200,
        scrollable: walletsList,
      );
      await tester.pumpAndSettle();

      final navigator = tester.state<NavigatorState>(
        find.byType(Navigator).first,
      );
      await tester.tap(
        find.byWidgetPredicate(
          (widget) =>
              widget is FloatingActionButton &&
              widget.heroTag == 'new-spending',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(SpendingSourceSheet), findsOneWidget);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      navigator.pop();
      await tester.pumpAndSettle();

      await tester.tap(
        find.descendant(
          of: find.byType(WalletCard),
          matching: find.text('Salário da empresa'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(WalletDetailPage), findsOneWidget);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));

      await tester.tap(find.byTooltip('Editar carteira'));
      await tester.pumpAndSettle();
      expect(find.byType(WalletFormPage), findsOneWidget);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      semantics.dispose();
    });
  }

  Future<void> pumpFirstRun(
    WidgetTester tester, {
    required Size size,
    String theme = 'light',
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    SharedPreferences.setMockInitialValues(<String, Object>{
      'theme_mode': theme,
    });

    final settings = SettingsViewModel();
    await settings.initialize();
    await tester.pumpWidget(
      AnchorApp(
        reminderNotifications: FakeReminderNotifications(),
        settings: settings,
        database: database,
        clock: () => DateTime(2026, 9, 15, 10),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'a configuração inicial não estoura em tela estreita com fonte ampliada',
    (tester) async {
      await pumpFirstRun(tester, size: const Size(320, 640));

      await fillOnboarding(tester);
      await tapVisible(tester, find.text('Ativar lembretes'));

      expect(find.byType(NavigationBar), findsOneWidget);
    },
  );

  for (final theme in ['light', 'dark']) {
    // Tall enough that no tap target sits half scrolled out of view, where
    // the guideline would measure only the visible sliver.
    testWidgets(
      'a configuração inicial tem alvos de toque e contraste suficientes ($theme)',
      (tester) async {
        final semantics = tester.ensureSemantics();
        await pumpFirstRun(tester, size: const Size(320, 2400), theme: theme);

        await fillOnboarding(
          tester,
          onFilled: (_) async {
            await expectLater(
              tester,
              meetsGuideline(androidTapTargetGuideline),
            );
            await expectLater(
              tester,
              meetsGuideline(labeledTapTargetGuideline),
            );
            await expectLater(tester, meetsGuideline(textContrastGuideline));
          },
        );
        semantics.dispose();
      },
    );
  }

  testWidgets('o botão de adicionar não cobre o último item das listas', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await seed();
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

    for (final (icon, page, item, heroTag) in [
      (Icons.receipt_long_outlined, ExpensesPage, ExpenseTile, 'new-expense'),
      (
        Icons.account_balance_wallet_outlined,
        WalletsPage,
        ListTile,
        'new-spending',
      ),
    ]) {
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.byIcon(icon),
        ),
      );
      await tester.pumpAndSettle();

      final list = find
          .descendant(
            of: find.byType(page),
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is Scrollable &&
                  widget.axisDirection == AxisDirection.down,
            ),
          )
          .first;
      await tester.fling(list, const Offset(0, -3000), 3000);
      await tester.pumpAndSettle();

      final items = find.descendant(
        of: find.byType(page),
        matching: find.byType(item),
      );
      final lastBottom = tester
          .widgetList(items)
          .map((tile) => tester.getRect(find.byWidget(tile)).bottom)
          .reduce((a, b) => a > b ? a : b);
      final fab = find.byWidgetPredicate(
        (widget) => widget is FloatingActionButton && widget.heroTag == heroTag,
      );
      expect(lastBottom, lessThanOrEqualTo(tester.getRect(fab).top));
      expect(tester.widget<FloatingActionButton>(fab).isExtended, isFalse);
    }
  });
}
