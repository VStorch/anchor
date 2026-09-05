import 'package:anchor/app/anchor_app.dart';
import 'package:anchor/core/database/app_database.dart';
import 'package:anchor/core/state/data_changes.dart';
import 'package:anchor/core/utils/month.dart';
import 'package:anchor/features/settings/viewmodels/settings_view_model.dart';
import 'package:anchor/features/wallets/models/payout.dart';
import 'package:anchor/features/wallets/models/payout_schedule.dart';
import 'package:anchor/features/wallets/models/receipt.dart';
import 'package:anchor/features/wallets/models/receipt_status.dart';
import 'package:anchor/features/wallets/models/wallet.dart';
import 'package:anchor/features/wallets/models/wallet_kind.dart';
import 'package:anchor/features/wallets/repositories/wallet_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/test_database.dart';

void main() {
  late AppDatabase database;
  late WalletRepository wallets;

  setUpAll(() => initializeDateFormatting('pt_BR'));

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    database = createInMemoryDatabase();
    wallets = WalletRepository(database, DataChanges());
  });

  tearDown(() => database.close());

  Future<int> seedSalary({required PayoutSchedule schedule, required int day}) {
    final month = Month.current();

    return wallets
        .saveWallet(
          Wallet(
            name: 'Salário',
            kind: WalletKind.salary,
            colorIndex: 0,
            createdAt: DateTime(month.year, month.month),
          ),
        )
        .then((walletId) async {
          await wallets.savePayout(
            Payout(
              walletId: walletId,
              label: 'Mensal',
              amount: 3000,
              day: day,
              schedule: schedule,
            ),
          );
          return walletId;
        });
  }

  Future<void> openAgenda(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);

    final settings = SettingsViewModel();
    await settings.initialize();
    await tester.pumpWidget(AnchorApp(settings: settings, database: database));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Agenda do mês'));
    await tester.pumpAndSettle();
  }

  testWidgets('marca o salário no dia útil, não no número da regra', (
    tester,
  ) async {
    await seedSalary(schedule: PayoutSchedule.businessDay, day: 5);
    await openAgenda(tester);

    final expectedDay = Month.current().businessDay(5).day;

    expect(find.text('Mensal'), findsOneWidget);
    expect(find.text('$expectedDay'), findsOneWidget);

    if (expectedDay != 5) {
      expect(
        find.text('5'),
        findsNothing,
        reason: 'o 5 é a ordem do dia útil, não a data',
      );
    }
  });

  testWidgets('mostra a entrada no dia em que ela caiu de verdade', (
    tester,
  ) async {
    final month = Month.current();
    final walletId = await seedSalary(
      schedule: PayoutSchedule.dayOfMonth,
      day: 1,
    );
    await wallets.registerDuePayouts(await wallets.fetchWallets());

    await wallets.saveReceipt(
      (await wallets.fetchReceipts()).single.copyWith(
        amount: 2980,
        receivedAt: DateTime(month.year, month.month, 3),
        status: ReceiptStatus.confirmed,
      ),
    );
    await wallets.saveReceipt(
      Receipt(
        walletId: walletId,
        month: month,
        amount: 200,
        receivedAt: DateTime(month.year, month.month, 7),
      ),
    );

    await openAgenda(tester);

    expect(find.text('3'), findsOneWidget);
    expect(find.textContaining('2.980,00'), findsOneWidget);
    expect(find.text('1'), findsNothing);

    expect(find.text('Entrada'), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
  });
}
