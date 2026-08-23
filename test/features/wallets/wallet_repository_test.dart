import 'package:anchor/core/database/app_database.dart';
import 'package:anchor/core/state/data_changes.dart';
import 'package:anchor/core/utils/month.dart';
import 'package:anchor/features/wallets/models/payout.dart';
import 'package:anchor/features/wallets/models/wallet.dart';
import 'package:anchor/features/wallets/models/wallet_kind.dart';
import 'package:anchor/features/wallets/repositories/wallet_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_database.dart';

void main() {
  late AppDatabase database;
  late WalletRepository repository;

  setUp(() {
    database = createInMemoryDatabase();
    repository = WalletRepository(database, DataChanges());
  });

  tearDown(() => database.close());

  Future<int> createSalary({DateTime? createdAt}) => repository.saveWallet(
    Wallet(
      name: 'Salário',
      kind: WalletKind.salary,
      colorIndex: 0,
      createdAt: createdAt ?? DateTime.now(),
    ),
  );

  test('guarda a carteira junto com o calendário de recebimentos', () async {
    final walletId = await createSalary();
    await repository.savePayout(
      Payout(
        walletId: walletId,
        label: 'Primeira parte',
        amount: 1500,
        dayOfMonth: 5,
      ),
    );
    await repository.savePayout(
      Payout(
        walletId: walletId,
        label: 'Segunda parte',
        amount: 900,
        dayOfMonth: 20,
      ),
    );

    final wallets = await repository.fetchWallets();

    expect(wallets, hasLength(1));
    expect(wallets.single.payouts, hasLength(2));
    expect(wallets.single.monthlyIncome, 2400);
    expect(wallets.single.payouts.map((payout) => payout.dayOfMonth), [5, 20]);
  });

  test('registra as entradas cujo dia já passou, sem duplicar', () async {
    final today = DateTime.now();
    final walletId = await createSalary(
      createdAt: DateTime(today.year, today.month, 1),
    );
    await repository.savePayout(
      Payout(walletId: walletId, label: 'Salário', amount: 3000, dayOfMonth: 1),
    );

    final wallets = await repository.fetchWallets();
    final created = await repository.registerDuePayouts(wallets);
    final again = await repository.registerDuePayouts(wallets);

    final receipts = await repository.fetchReceipts();

    expect(created, 1);
    expect(again, 0);
    expect(receipts, hasLength(1));
    expect(receipts.single.month, Month.current());
    expect(receipts.single.amount, 3000);
  });

  test('não registra entrada de um dia que ainda não chegou', () async {
    final walletId = await createSalary(createdAt: DateTime.now());
    await repository.savePayout(
      Payout(
        walletId: walletId,
        label: 'Salário',
        amount: 3000,
        dayOfMonth: 31,
      ),
    );

    final wallets = await repository.fetchWallets();
    await repository.registerDuePayouts(wallets);

    final receipts = await repository.fetchReceipts();
    final lastDayHasPassed = Month.current().dayOf(31).isBefore(DateTime.now());

    expect(receipts, hasLength(lastDayHasPassed ? 1 : 0));
  });

  test('apagar a carteira leva junto o calendário e as entradas', () async {
    final walletId = await createSalary(
      createdAt: DateTime(DateTime.now().year, DateTime.now().month, 1),
    );
    await repository.savePayout(
      Payout(walletId: walletId, label: 'Salário', amount: 3000, dayOfMonth: 1),
    );
    await repository.registerDuePayouts(await repository.fetchWallets());

    await repository.deleteWallet(walletId);

    expect(await repository.fetchWallets(), isEmpty);
    expect(await repository.fetchReceipts(), isEmpty);
  });
}
