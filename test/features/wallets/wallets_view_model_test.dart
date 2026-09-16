import 'package:anchor/core/database/app_database.dart';
import 'package:anchor/core/state/data_changes.dart';
import 'package:anchor/core/state/month_selection.dart';
import 'package:anchor/features/budget/services/budget_service.dart';
import 'package:anchor/features/cards/repositories/card_repository.dart';
import 'package:anchor/features/expenses/repositories/expense_repository.dart';
import 'package:anchor/core/utils/month.dart';
import 'package:anchor/features/wallets/models/outflow.dart';
import 'package:anchor/features/wallets/models/receipt.dart';
import 'package:anchor/features/wallets/models/receipt_status.dart';
import 'package:anchor/features/wallets/models/wallet.dart';
import 'package:anchor/features/wallets/models/wallet_kind.dart';
import 'package:anchor/features/wallets/repositories/wallet_repository.dart';
import 'package:anchor/features/wallets/viewmodels/wallets_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_database.dart';

void main() {
  final now = DateTime(2026, 9, 13, 18, 30);

  test('o saldo informado para hoje vale a partir de agora', () {
    expect(WalletsViewModel.checkedAtFor(DateTime(2026, 9, 13), now: now), now);
  });

  test('o saldo informado para um dia passado fecha aquele dia', () {
    expect(
      WalletsViewModel.checkedAtFor(DateTime(2026, 9, 10), now: now),
      DateTime(2026, 9, 10, 23, 59, 59, 999),
    );
  });

  group('saldos informados repetidos', () {
    late AppDatabase database;
    late WalletRepository wallets;
    late WalletsViewModel viewModel;
    late Wallet wallet;

    setUp(() async {
      database = createInMemoryDatabase();
      final changes = DataChanges();
      wallets = WalletRepository(database, changes);
      viewModel = WalletsViewModel(
        budgetService: BudgetService(
          ExpenseRepository(database, changes),
          wallets,
          CardRepository(database, changes),
        ),
        walletRepository: wallets,
        monthSelection: MonthSelection(),
        changes: changes,
      );
      final today = DateTime.now();
      await wallets.saveWallet(
        Wallet(
          name: 'Salário',
          kind: WalletKind.salary,
          colorIndex: 0,
          createdAt: DateTime(today.year, today.month - 2),
        ),
      );
      await viewModel.initialize();
      wallet = viewModel.wallets.single;
    });

    tearDown(() async {
      viewModel.dispose();
      await database.close();
    });

    Future<double> balance() async {
      await viewModel.refresh();
      return viewModel.summaryFor(wallet.id!)!.balance;
    }

    test('um dia passado guarda um saldo só, o último informado', () async {
      final today = DateTime.now();
      final yesterday = DateTime(today.year, today.month, today.day - 1);

      await viewModel.saveBalanceCheck(wallet, amount: 500, day: yesterday);
      await viewModel.refresh();
      expect(viewModel.checkOnDay(wallet, yesterday)?.amount, 500);
      await viewModel.saveBalanceCheck(wallet, amount: 700, day: yesterday);

      final checks = await wallets.fetchBalanceChecks();
      expect(checks, hasLength(1));
      expect(checks.single.amount, 700);
      expect(await balance(), 700);
    });

    test('hoje aceita vários saldos, em instantes distintos', () async {
      final today = DateTime.now();

      await viewModel.saveBalanceCheck(wallet, amount: 500, day: today);
      await viewModel.refresh();
      expect(viewModel.checkOnDay(wallet, today), isNull);
      await viewModel.saveBalanceCheck(wallet, amount: 700, day: today);
      await viewModel.refresh();

      expect(await wallets.fetchBalanceChecks(), hasLength(2));
    });

    test('editar só o valor de um saldo antigo mantém o instante e não muda '
        'o saldo de hoje', () async {
      final today = DateTime.now();
      final yesterday = DateTime(today.year, today.month, today.day - 1);
      await viewModel.saveBalanceCheck(wallet, amount: 500, day: yesterday);
      await viewModel.saveBalanceCheck(wallet, amount: 900, day: today);
      await viewModel.refresh();
      final old = (await wallets.fetchBalanceChecks()).first;
      expect(viewModel.isLatestCheck(old), isFalse);

      await viewModel.saveBalanceCheck(
        wallet,
        amount: 800,
        day: old.checkedAt,
        editing: old,
      );

      final edited = (await wallets.fetchBalanceChecks()).first;
      expect(edited.checkedAt, old.checkedAt);
      expect(edited.amount, 800);
      expect(await balance(), 900);

      await wallets.saveOutflow(
        Outflow(
          walletId: wallet.id!,
          description: 'hoje',
          amount: 20,
          spentAt: DateTime.now(),
        ),
      );
      expect(await balance(), 880);
    });

    test('o extrato de uma carteira só traz os movimentos dela', () async {
      final otherId = await wallets.saveWallet(
        Wallet(
          name: 'VR',
          kind: WalletKind.benefit,
          colorIndex: 1,
          createdAt: DateTime.now(),
        ),
      );
      await wallets.saveOutflow(
        Outflow(
          walletId: wallet.id!,
          description: 'Mercado',
          amount: 30,
          spentAt: DateTime.now(),
        ),
      );
      await wallets.saveOutflow(
        Outflow(
          walletId: otherId,
          description: 'Padaria',
          amount: 12,
          spentAt: DateTime.now(),
        ),
      );
      await viewModel.refresh();

      expect(
        viewModel.movementsOf(wallet.id!).map((movement) => movement.title),
        ['Mercado'],
      );
      expect(viewModel.movementsOf(otherId).map((movement) => movement.title), [
        'Padaria',
      ]);
    });

    test('confirmar abre a primeira entrada ainda prevista do mês', () async {
      final month = Month.current();
      for (final day in [20, 1]) {
        await wallets.saveReceipt(
          Receipt(
            walletId: wallet.id!,
            month: month,
            amount: 1000,
            receivedAt: month.dayOf(day),
            status: ReceiptStatus.predicted,
          ),
        );
      }
      await viewModel.refresh();

      final first = viewModel.firstUnconfirmedOf(wallet)!;
      expect(first.receivedAt.day, 1);

      await viewModel.confirmReceipt(
        first,
        amount: 1000,
        receivedAt: first.receivedAt,
      );
      await viewModel.refresh();

      expect(viewModel.firstUnconfirmedOf(wallet)?.receivedAt.day, 20);
    });
  });
}
