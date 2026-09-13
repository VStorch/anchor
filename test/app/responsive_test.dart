import 'package:anchor/app/anchor_app.dart';
import 'package:anchor/core/database/app_database.dart';
import 'package:anchor/core/state/data_changes.dart';
import 'package:anchor/core/utils/month.dart';
import 'package:anchor/features/expenses/models/expense.dart';
import 'package:anchor/features/expenses/models/expense_payment.dart';
import 'package:anchor/features/expenses/models/expense_type.dart';
import 'package:anchor/features/expenses/repositories/expense_repository.dart';
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
    SharedPreferences.setMockInitialValues(<String, Object>{});
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
      Payout(walletId: salaryId, label: 'Mensal', amount: 12345.67, day: 1),
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
      Payout(walletId: voucherId, label: 'Mensal', amount: 1234.56, day: 1),
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

    final saved = await expenses.fetchExpenses();
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
    });
  }
}
