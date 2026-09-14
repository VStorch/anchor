import 'package:anchor/core/database/app_database.dart';
import 'package:anchor/core/state/data_changes.dart';
import 'package:anchor/core/utils/month.dart';
import 'package:anchor/features/budget/services/budget_service.dart';
import 'package:anchor/features/cards/repositories/card_repository.dart';
import 'package:anchor/features/expenses/models/expense.dart';
import 'package:anchor/features/expenses/models/expense_type.dart';
import 'package:anchor/features/expenses/repositories/expense_repository.dart';
import 'package:anchor/features/wallets/models/balance_check.dart';
import 'package:anchor/features/wallets/models/payout.dart';
import 'package:anchor/features/wallets/models/payout_schedule.dart';
import 'package:anchor/features/wallets/models/wallet.dart';
import 'package:anchor/features/wallets/models/wallet_kind.dart';
import 'package:anchor/features/wallets/repositories/wallet_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_database.dart';

void main() {
  const september = Month(2026, 9);
  const october = Month(2026, 10);
  final now = DateTime(2026, 9, 13, 18);

  late AppDatabase database;
  late WalletRepository wallets;
  late ExpenseRepository expenses;
  late BudgetService service;

  setUp(() {
    database = createInMemoryDatabase();
    final changes = DataChanges();
    wallets = WalletRepository(database, changes);
    expenses = ExpenseRepository(database, changes);
    service = BudgetService(
      expenses,
      wallets,
      CardRepository(database, changes),
    );
  });

  tearDown(() => database.close());

  Future<int> walletWith({
    required String name,
    required WalletKind kind,
    required Payout payout,
  }) async {
    final id = await wallets.saveWallet(
      Wallet(
        name: name,
        kind: kind,
        colorIndex: 0,
        createdAt: DateTime(2026, 9),
      ),
    );
    await wallets.savePayout(payout.copyWith(walletId: id));
    return id;
  }

  Future<void> seedSeptember() async {
    final salaryId = await walletWith(
      name: 'Salário',
      kind: WalletKind.salary,
      payout: Payout(
        walletId: 0,
        label: 'Mensal',
        amount: 3200,
        day: 5,
        schedule: PayoutSchedule.businessDay,
        createdAt: DateTime(2026, 9),
      ),
    );
    final voucherId = await walletWith(
      name: 'Vale refeição',
      kind: WalletKind.benefit,
      payout: Payout(
        walletId: 0,
        label: 'Mensal',
        amount: 600,
        day: 1,
        createdAt: DateTime(2026, 9),
      ),
    );

    await wallets.registerDuePayouts(await wallets.fetchWallets(), now: now);
    final received = await wallets.fetchReceipts();
    await wallets.saveBalanceCheck(
      BalanceCheck(walletId: salaryId, amount: 850, checkedAt: now),
      confirm: received.where((r) => r.walletId == salaryId).toList(),
    );
    await wallets.saveBalanceCheck(
      BalanceCheck(walletId: voucherId, amount: 162.70, checkedAt: now),
      confirm: received.where((r) => r.walletId == voucherId).toList(),
    );

    await expenses.saveExpense(
      Expense(
        name: 'Aluguel',
        type: ExpenseType.recurring,
        amount: 464.90,
        dueDay: 20,
        startMonth: september,
        walletId: salaryId,
        createdAt: DateTime(2026, 9),
      ),
    );
    await expenses.saveExpense(
      Expense(
        name: 'IPVA',
        type: ExpenseType.single,
        amount: 300,
        dueDay: 15,
        startMonth: october,
        createdAt: DateTime(2026, 9),
      ),
    );
  }

  group('BudgetService.loadSnapshot', () {
    test('mostra o que se tem hoje e o que vai sobrar em setembro', () async {
      await seedSeptember();

      final snapshot = await service.loadSnapshot(september, now: now);

      expect(snapshot.walletsBalance, 1012.70);
      expect(snapshot.awaitingConfirmation, 0);
      expect(snapshot.summary.difference, 3800);
      expect(snapshot.forecast!.toPay, 464.90);
      expect(snapshot.forecast!.endBalance, 547.80);
    });

    test(
      'em outubro soma o salário e o vale previstos e desconta as contas',
      () async {
        await seedSeptember();

        final snapshot = await service.loadSnapshot(october, now: now);
        final forecast = snapshot.forecast!;

        expect(snapshot.walletsBalance, 1012.70);
        expect(forecast.toReceive, 3800);
        expect(forecast.toPay, 1229.80);
        expect(forecast.unassignedToPay, 300);
        expect(forecast.wallets.first.endBalance, 850 + 3200 - 929.80);
        expect(forecast.endBalance, 3582.90);
      },
    );

    test('não prevê um mês que já passou', () async {
      await seedSeptember();

      final snapshot = await service.loadSnapshot(
        const Month(2026, 8),
        now: now,
      );

      expect(snapshot.forecast, isNull);
    });

    test('pede para confirmar o que o calendário já trouxe', () async {
      final id = await walletWith(
        name: 'Salário',
        kind: WalletKind.salary,
        payout: Payout(
          walletId: 0,
          label: 'Mensal',
          amount: 3000,
          day: 1,
          createdAt: DateTime(2026, 9),
        ),
      );

      final snapshot = await service.loadSnapshot(october, now: now);

      expect(snapshot.summaryFor(id)!.balance, 0);
      expect(snapshot.awaitingConfirmation, 3000);
      expect(snapshot.forecast!.toReceive, 6000);
    });
  });
}
