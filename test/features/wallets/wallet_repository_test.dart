import 'package:anchor/core/database/app_database.dart';
import 'package:anchor/core/state/data_changes.dart';
import 'package:anchor/core/utils/month.dart';
import 'package:anchor/features/wallets/models/payout.dart';
import 'package:anchor/features/wallets/models/payout_schedule.dart';
import 'package:anchor/features/wallets/models/receipt_kind.dart';
import 'package:anchor/features/wallets/models/receipt_status.dart';
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
      Payout(walletId: walletId, label: 'Primeira parte', amount: 1500, day: 5),
    );
    await repository.savePayout(
      Payout(walletId: walletId, label: 'Segunda parte', amount: 900, day: 20),
    );

    final wallets = await repository.fetchWallets();

    expect(wallets, hasLength(1));
    expect(wallets.single.payouts, hasLength(2));
    expect(wallets.single.monthlyIncome, 2400);
    expect(wallets.single.payouts.map((payout) => payout.day), [5, 20]);
  });

  test('registra as entradas cujo dia já passou, sem duplicar', () async {
    final today = DateTime.now();
    final walletId = await createSalary(
      createdAt: DateTime(today.year, today.month, 1),
    );
    await repository.savePayout(
      Payout(walletId: walletId, label: 'Salário', amount: 3000, day: 1),
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
      Payout(walletId: walletId, label: 'Salário', amount: 3000, day: 31),
    );

    final wallets = await repository.fetchWallets();
    await repository.registerDuePayouts(wallets);

    final receipts = await repository.fetchReceipts();
    final lastDayHasPassed = Month.current().dayOf(31).isBefore(DateTime.now());

    expect(receipts, hasLength(lastDayHasPassed ? 1 : 0));
  });

  test('a entrada gerada pelo calendário nasce prevista', () async {
    final today = DateTime.now();
    final walletId = await createSalary(
      createdAt: DateTime(today.year, today.month, 1),
    );
    await repository.savePayout(
      Payout(walletId: walletId, label: 'Salário', amount: 3000, day: 1),
    );

    await repository.registerDuePayouts(await repository.fetchWallets());
    final receipt = (await repository.fetchReceipts()).single;

    expect(receipt.status, ReceiptStatus.predicted);
    expect(receipt.isPredicted, isTrue);
  });

  test('confirmar a entrada guarda o dia e o valor reais', () async {
    final today = DateTime.now();
    final walletId = await createSalary(
      createdAt: DateTime(today.year, today.month, 1),
    );
    await repository.savePayout(
      Payout(walletId: walletId, label: 'Salário', amount: 3000, day: 1),
    );
    await repository.registerDuePayouts(await repository.fetchWallets());

    final predicted = (await repository.fetchReceipts()).single;
    await repository.saveReceipt(
      predicted.copyWith(
        amount: 3120.45,
        receivedAt: DateTime(today.year, today.month, 4),
        status: ReceiptStatus.confirmed,
      ),
    );

    final receipt = (await repository.fetchReceipts()).single;

    expect(receipt.amount, 3120.45);
    expect(receipt.receivedAt.day, 4);
    expect(receipt.status, ReceiptStatus.confirmed);
    expect(receipt.month, predicted.month);
  });

  test('a entrada descartada não volta a ser criada', () async {
    final today = DateTime.now();
    final walletId = await createSalary(
      createdAt: DateTime(today.year, today.month, 1),
    );
    await repository.savePayout(
      Payout(walletId: walletId, label: 'Salário', amount: 3000, day: 1),
    );
    await repository.registerDuePayouts(await repository.fetchWallets());

    await repository.discardReceipt((await repository.fetchReceipts()).single);
    await repository.registerDuePayouts(await repository.fetchWallets());

    final receipts = await repository.fetchReceipts();

    expect(receipts, hasLength(1));
    expect(receipts.single.status, ReceiptStatus.skipped);
    expect(receipts.single.counts, isFalse);
  });

  test('mudar o valor do salário reajusta a entrada ainda prevista', () async {
    final today = DateTime.now();
    final walletId = await createSalary(
      createdAt: DateTime(today.year, today.month, 1),
    );
    await repository.savePayout(
      Payout(walletId: walletId, label: 'Salário', amount: 3000, day: 1),
    );
    await repository.registerDuePayouts(await repository.fetchWallets());

    final payout = (await repository.fetchWallets()).single.payouts.single;
    await repository.savePayout(payout.copyWith(amount: 3500));
    await repository.registerDuePayouts(await repository.fetchWallets());

    final receipts = await repository.fetchReceipts();

    expect(receipts, hasLength(1));
    expect(receipts.single.amount, 3500);
  });

  test('a entrada confirmada não é reajustada pelo calendário', () async {
    final today = DateTime.now();
    final walletId = await createSalary(
      createdAt: DateTime(today.year, today.month, 1),
    );
    await repository.savePayout(
      Payout(walletId: walletId, label: 'Salário', amount: 3000, day: 1),
    );
    await repository.registerDuePayouts(await repository.fetchWallets());

    await repository.saveReceipt(
      (await repository.fetchReceipts()).single.copyWith(
        amount: 2900,
        status: ReceiptStatus.confirmed,
      ),
    );

    final payout = (await repository.fetchWallets()).single.payouts.single;
    await repository.savePayout(payout.copyWith(amount: 3500));
    await repository.registerDuePayouts(await repository.fetchWallets());

    expect((await repository.fetchReceipts()).single.amount, 2900);
  });

  test('o recebimento por dia útil cai no dia útil do mês', () async {
    final walletId = await createSalary(createdAt: DateTime(2026, 9));
    await repository.savePayout(
      Payout(
        walletId: walletId,
        label: 'Salário',
        amount: 3000,
        day: 5,
        schedule: PayoutSchedule.businessDay,
      ),
    );

    final payout = (await repository.fetchWallets()).single.payouts.single;

    expect(payout.dateIn(const Month(2026, 9)), DateTime(2026, 9, 7));
    expect(payout.scheduleLabel, '5º dia útil');
  });

  test('editar a carteira preserva o calendário e as entradas', () async {
    final today = DateTime.now();
    final walletId = await createSalary(
      createdAt: DateTime(today.year, today.month, 1),
    );
    await repository.savePayout(
      Payout(walletId: walletId, label: 'Salário', amount: 3000, day: 1),
    );
    await repository.registerDuePayouts(await repository.fetchWallets());

    final wallet = (await repository.fetchWallets()).single;
    await repository.saveWallet(wallet.copyWith(name: 'Salário CLT'));

    final saved = (await repository.fetchWallets()).single;

    expect(saved.id, walletId);
    expect(saved.name, 'Salário CLT');
    expect(saved.payouts, hasLength(1));
    expect(await repository.fetchReceipts(), hasLength(1));
  });

  test('ajustar o saldo lança só a diferença', () async {
    final walletId = await createSalary(createdAt: DateTime.now());
    final wallet = (await repository.fetchWallets()).single;

    await repository.adjustBalance(
      wallet: wallet,
      currentBalance: 0,
      targetBalance: 2000,
    );
    await repository.adjustBalance(
      wallet: wallet,
      currentBalance: 2000,
      targetBalance: 1750.30,
    );

    final receipts = await repository.fetchReceipts();

    expect(walletId, wallet.id);
    expect(receipts, hasLength(2));
    expect(receipts.every((receipt) => receipt.isAdjustment), isTrue);
    expect(
      receipts.fold<double>(0, (total, receipt) => total + receipt.amount),
      closeTo(1750.30, 0.001),
    );
  });

  test('ajustar para o saldo que já está não lança nada', () async {
    await createSalary(createdAt: DateTime.now());
    final wallet = (await repository.fetchWallets()).single;

    await repository.adjustBalance(
      wallet: wallet,
      currentBalance: 1200,
      targetBalance: 1200,
    );

    expect(await repository.fetchReceipts(), isEmpty);
  });

  test('o ajuste de saldo é uma entrada manual removível', () async {
    await createSalary(createdAt: DateTime.now());
    final wallet = (await repository.fetchWallets()).single;

    await repository.adjustBalance(
      wallet: wallet,
      currentBalance: 0,
      targetBalance: 500,
    );

    final adjustment = (await repository.fetchReceipts()).single;

    expect(adjustment.kind, ReceiptKind.adjustment);
    expect(adjustment.isManual, isTrue);

    await repository.discardReceipt(adjustment);

    expect(await repository.fetchReceipts(), isEmpty);
  });

  test('apagar a carteira leva junto o calendário e as entradas', () async {
    final walletId = await createSalary(
      createdAt: DateTime(DateTime.now().year, DateTime.now().month, 1),
    );
    await repository.savePayout(
      Payout(walletId: walletId, label: 'Salário', amount: 3000, day: 1),
    );
    await repository.registerDuePayouts(await repository.fetchWallets());

    await repository.deleteWallet(walletId);

    expect(await repository.fetchWallets(), isEmpty);
    expect(await repository.fetchReceipts(), isEmpty);
  });
}
