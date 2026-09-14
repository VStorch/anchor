import 'package:anchor/core/database/app_database.dart';
import 'package:anchor/core/state/data_changes.dart';
import 'package:anchor/core/utils/month.dart';
import 'package:anchor/features/expenses/models/expense.dart';
import 'package:anchor/features/expenses/models/expense_payment.dart';
import 'package:anchor/features/expenses/models/expense_type.dart';
import 'package:anchor/features/expenses/repositories/expense_repository.dart';
import 'package:anchor/features/wallets/models/balance_check.dart';
import 'package:anchor/features/wallets/models/outflow.dart';
import 'package:anchor/features/wallets/models/payout.dart';
import 'package:anchor/features/wallets/models/payout_schedule.dart';
import 'package:anchor/features/wallets/models/receipt.dart';
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
      Payout(
        walletId: walletId,
        label: 'Primeira parte',
        amount: 1500,
        day: 5,
        createdAt: DateTime.now(),
      ),
    );
    await repository.savePayout(
      Payout(
        walletId: walletId,
        label: 'Segunda parte',
        amount: 900,
        day: 20,
        createdAt: DateTime.now(),
      ),
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
      Payout(
        walletId: walletId,
        label: 'Salário',
        amount: 3000,
        day: 1,
        createdAt: DateTime(today.year, today.month, 1),
      ),
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
        day: 31,
        createdAt: DateTime.now(),
      ),
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
      Payout(
        walletId: walletId,
        label: 'Salário',
        amount: 3000,
        day: 1,
        createdAt: DateTime(today.year, today.month, 1),
      ),
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
      Payout(
        walletId: walletId,
        label: 'Salário',
        amount: 3000,
        day: 1,
        createdAt: DateTime(today.year, today.month, 1),
      ),
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
      Payout(
        walletId: walletId,
        label: 'Salário',
        amount: 3000,
        day: 1,
        createdAt: DateTime(today.year, today.month, 1),
      ),
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
      Payout(
        walletId: walletId,
        label: 'Salário',
        amount: 3000,
        day: 1,
        createdAt: DateTime(today.year, today.month, 1),
      ),
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
      Payout(
        walletId: walletId,
        label: 'Salário',
        amount: 3000,
        day: 1,
        createdAt: DateTime(today.year, today.month, 1),
      ),
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
        createdAt: DateTime(2026, 9),
      ),
    );

    final payout = (await repository.fetchWallets()).single.payouts.single;

    expect(payout.dateIn(const Month(2026, 9)), DateTime(2026, 9, 8));
    expect(payout.scheduleLabel, '5º dia útil');
  });

  test('editar a carteira preserva o calendário e as entradas', () async {
    final today = DateTime.now();
    final walletId = await createSalary(
      createdAt: DateTime(today.year, today.month, 1),
    );
    await repository.savePayout(
      Payout(
        walletId: walletId,
        label: 'Salário',
        amount: 3000,
        day: 1,
        createdAt: DateTime(today.year, today.month, 1),
      ),
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

  group('saldo informado', () {
    Future<Wallet> seedPredictedSalary() async {
      final today = DateTime.now();
      final walletId = await createSalary(
        createdAt: DateTime(today.year, today.month, 1),
      );
      await repository.savePayout(
        Payout(
          walletId: walletId,
          label: 'Mensal',
          amount: 3200,
          day: 1,
          createdAt: DateTime(today.year, today.month, 1),
        ),
      );
      await repository.registerDuePayouts(await repository.fetchWallets());
      return (await repository.fetchWallets()).single;
    }

    test(
      'guarda o valor e confirma a entrada que já caiu de uma vez',
      () async {
        final changes = DataChanges();
        repository = WalletRepository(database, changes);
        final wallet = await seedPredictedSalary();
        final predicted = (await repository.fetchReceipts()).single;

        var published = 0;
        changes.addListener(() => published++);
        final checkedAt = DateTime.now();
        await repository.saveBalanceCheck(
          BalanceCheck(walletId: wallet.id!, amount: 850, checkedAt: checkedAt),
          confirm: [predicted],
        );

        final check = (await repository.fetchBalanceChecks()).single;
        final receipt = (await repository.fetchReceipts()).single;
        expect(published, 1);
        expect(check.amount, 850);
        expect(check.checkedAt, checkedAt);
        expect(receipt.status, ReceiptStatus.confirmed);
        expect(receipt.receivedAt, predicted.receivedAt);
      },
    );

    test('se a confirmação falha, o saldo informado não é gravado', () async {
      final wallet = await seedPredictedSalary();
      final predicted = (await repository.fetchReceipts()).single;
      final orphan = Receipt(
        id: predicted.id,
        walletId: 999,
        month: predicted.month,
        amount: predicted.amount,
        receivedAt: predicted.receivedAt,
        status: ReceiptStatus.predicted,
      );

      await expectLater(
        repository.saveBalanceCheck(
          BalanceCheck(
            walletId: wallet.id!,
            amount: 850,
            checkedAt: DateTime.now(),
          ),
          confirm: [orphan],
        ),
        throwsA(anything),
      );

      expect(await repository.fetchBalanceChecks(), isEmpty);
      expect((await repository.fetchReceipts()).single.isPredicted, isTrue);
    });

    test('editar e remover o saldo informado', () async {
      final wallet = await seedPredictedSalary();
      await repository.saveBalanceCheck(
        BalanceCheck(
          walletId: wallet.id!,
          amount: 850,
          checkedAt: DateTime.now(),
        ),
      );
      final check = (await repository.fetchBalanceChecks()).single;

      await repository.saveBalanceCheck(check.copyWith(amount: -120.5));
      final edited = (await repository.fetchBalanceChecks()).single;
      expect(edited.id, check.id);
      expect(edited.amount, -120.5);

      await repository.deleteBalanceCheck(edited.id!);
      expect(await repository.fetchBalanceChecks(), isEmpty);
    });

    test('apagar a carteira leva junto o saldo informado', () async {
      final wallet = await seedPredictedSalary();
      await repository.saveBalanceCheck(
        BalanceCheck(
          walletId: wallet.id!,
          amount: 850,
          checkedAt: DateTime.now(),
        ),
      );

      await repository.deleteWallet(wallet.id!);

      expect(await repository.fetchBalanceChecks(), isEmpty);
    });
  });

  test('apagar a carteira mantém pagas as contas pagas com ela', () async {
    final walletId = await createSalary();
    final expenses = ExpenseRepository(database, DataChanges());
    await expenses.saveExpense(
      Expense(
        name: 'Aluguel',
        type: ExpenseType.recurring,
        amount: 1100,
        dueDay: 10,
        startMonth: Month.current(),
        walletId: walletId,
        createdAt: DateTime.now(),
      ),
    );
    final expenseId = (await expenses.fetchExpenses()).single.id!;
    await expenses.savePayment(
      ExpensePayment(
        expenseId: expenseId,
        walletId: walletId,
        month: Month.current(),
        amount: 1100,
        paidAt: DateTime.now(),
      ),
    );

    await repository.deleteWallet(walletId);

    final payment = (await expenses.fetchPayments()).single;
    expect(payment.walletId, isNull);
    expect(payment.settledOutside, isTrue);
    expect(payment.amount, 1100);
  });

  test('remover o recebimento preserva as entradas já confirmadas', () async {
    final today = DateTime.now();
    final walletId = await createSalary(
      createdAt: DateTime(today.year, today.month, 1),
    );
    await repository.savePayout(
      Payout(
        walletId: walletId,
        label: 'Salário',
        amount: 3000,
        day: 1,
        createdAt: DateTime(today.year, today.month, 1),
      ),
    );
    await repository.registerDuePayouts(await repository.fetchWallets());

    await repository.saveReceipt(
      (await repository.fetchReceipts()).single.copyWith(
        amount: 2980,
        status: ReceiptStatus.confirmed,
      ),
    );

    final payout = (await repository.fetchWallets()).single.payouts.single;
    await repository.deletePayout(payout.id!);

    final receipts = await repository.fetchReceipts();

    expect((await repository.fetchWallets()).single.payouts, isEmpty);
    expect(receipts, hasLength(1));
    expect(receipts.single.amount, 2980);
    expect(receipts.single.payoutId, isNull);
    expect(receipts.single.isManual, isTrue);
  });

  test('remover o recebimento leva junto o que ainda era previsto', () async {
    final today = DateTime.now();
    final walletId = await createSalary(
      createdAt: DateTime(today.year, today.month, 1),
    );
    await repository.savePayout(
      Payout(
        walletId: walletId,
        label: 'Salário',
        amount: 3000,
        day: 1,
        createdAt: DateTime(today.year, today.month, 1),
      ),
    );
    await repository.registerDuePayouts(await repository.fetchWallets());

    final payout = (await repository.fetchWallets()).single.payouts.single;
    await repository.deletePayout(payout.id!);

    expect(await repository.fetchReceipts(), isEmpty);
  });

  test('o gasto avulso sai do saldo da carteira', () async {
    final walletId = await createSalary(createdAt: DateTime.now());

    await repository.saveOutflow(
      Outflow(
        walletId: walletId,
        description: 'Mercado',
        amount: 47.90,
        spentAt: DateTime.now(),
      ),
    );

    final outflow = (await repository.fetchOutflows()).single;

    expect(outflow.amount, 47.90);
    expect(outflow.description, 'Mercado');
    expect(outflow.month, Month.current());
  });

  test('o gasto sem descrição ganha um rótulo', () async {
    final walletId = await createSalary(createdAt: DateTime.now());

    await repository.saveOutflow(
      Outflow(
        walletId: walletId,
        description: '   ',
        amount: 20,
        spentAt: DateTime.now(),
      ),
    );

    expect((await repository.fetchOutflows()).single.label, 'Gasto');
  });

  test('apagar a carteira leva junto os gastos avulsos', () async {
    final walletId = await createSalary(createdAt: DateTime.now());
    await repository.saveOutflow(
      Outflow(
        walletId: walletId,
        description: 'Mercado',
        amount: 47.90,
        spentAt: DateTime.now(),
      ),
    );

    await repository.deleteWallet(walletId);

    expect(await repository.fetchOutflows(), isEmpty);
  });

  test('apagar a carteira leva junto o calendário e as entradas', () async {
    final walletId = await createSalary(
      createdAt: DateTime(DateTime.now().year, DateTime.now().month, 1),
    );
    await repository.savePayout(
      Payout(
        walletId: walletId,
        label: 'Salário',
        amount: 3000,
        day: 1,
        createdAt: DateTime.now(),
      ),
    );
    await repository.registerDuePayouts(await repository.fetchWallets());

    await repository.deleteWallet(walletId);

    expect(await repository.fetchWallets(), isEmpty);
    expect(await repository.fetchReceipts(), isEmpty);
  });

  test(
    'passar o dia do salário para depois de hoje move a entrada prevista',
    () async {
      final today = DateTime.now();
      final month = Month.current();
      final lastDay = month.dayOf(31);
      if (!lastDay.isAfter(DateTime(today.year, today.month, today.day))) {
        markTestSkipped('hoje já é o último dia do mês');
        return;
      }
      final walletId = await createSalary(
        createdAt: DateTime(today.year, today.month, 1),
      );
      await repository.savePayout(
        Payout(
          walletId: walletId,
          label: 'Salário',
          amount: 3000,
          day: 1,
          createdAt: DateTime(today.year, today.month, 1),
        ),
      );
      await repository.registerDuePayouts(await repository.fetchWallets());

      final payout = (await repository.fetchWallets()).single.payouts.single;
      await repository.savePayout(payout.copyWith(day: 31, amount: 3200));
      await repository.registerDuePayouts(await repository.fetchWallets());

      final receipt = (await repository.fetchReceipts()).single;
      expect(receipt.receivedAt, lastDay);
      expect(receipt.amount, 3200);
      expect(receipt.isPredicted, isTrue);
    },
  );

  test(
    'o recebimento novo numa carteira antiga não gera meses passados',
    () async {
      final month = Month.current();
      final walletStart = month.addMonths(-8);
      final walletId = await createSalary(
        createdAt: DateTime(walletStart.year, walletStart.month),
      );
      await repository.savePayout(
        Payout(
          walletId: walletId,
          label: 'Salário',
          amount: 3000,
          day: 1,
          createdAt: DateTime.now(),
        ),
      );

      await repository.registerDuePayouts(await repository.fetchWallets());

      final receipts = await repository.fetchReceipts();
      expect(receipts, hasLength(1));
      expect(receipts.single.month, month);
    },
  );

  test(
    'excluir e recriar o recebimento não volta aos meses passados',
    () async {
      final month = Month.current();
      final walletStart = month.addMonths(-3);
      final walletId = await createSalary(
        createdAt: DateTime(walletStart.year, walletStart.month),
      );
      await repository.savePayout(
        Payout(
          walletId: walletId,
          label: 'Salário',
          amount: 3000,
          day: 1,
          createdAt: DateTime(walletStart.year, walletStart.month),
        ),
      );
      await repository.registerDuePayouts(await repository.fetchWallets());

      final original = (await repository.fetchWallets()).single.payouts.single;
      await repository.deletePayout(original.id!);
      await repository.savePayout(
        Payout(
          walletId: walletId,
          label: 'Salário',
          amount: 3000,
          day: 1,
          createdAt: DateTime.now(),
        ),
      );
      await repository.registerDuePayouts(await repository.fetchWallets());

      final receipts = await repository.fetchReceipts();
      expect(receipts, hasLength(1));
      expect(receipts.single.month, month);
      expect(receipts.single.isPredicted, isTrue);
    },
  );

  test('mudar o valor do salário não reescreve os meses passados', () async {
    final month = Month.current();
    final twoMonthsAgo = month.addMonths(-2);
    final walletId = await createSalary(
      createdAt: DateTime(twoMonthsAgo.year, twoMonthsAgo.month, 1),
    );
    await repository.savePayout(
      Payout(
        walletId: walletId,
        label: 'Salário',
        amount: 3000,
        day: 1,
        createdAt: DateTime(twoMonthsAgo.year, twoMonthsAgo.month, 1),
      ),
    );
    await repository.registerDuePayouts(await repository.fetchWallets());

    final payout = (await repository.fetchWallets()).single.payouts.single;
    await repository.savePayout(payout.copyWith(amount: 3500));
    await repository.registerDuePayouts(await repository.fetchWallets());

    final amountByMonth = {
      for (final receipt in await repository.fetchReceipts())
        receipt.month: receipt.amount,
    };
    expect(amountByMonth, {
      twoMonthsAgo: 3000,
      month.previous: 3000,
      month: 3500,
    });
  });

  group('salvar a carteira com o calendário', () {
    Future<Wallet> seedWithTwoPayouts() async {
      final today = DateTime.now();
      final walletId = await createSalary(
        createdAt: DateTime(today.year, today.month, 1),
      );
      for (final label in ['Adiantamento', 'Salário']) {
        await repository.savePayout(
          Payout(
            walletId: walletId,
            label: label,
            amount: 1500,
            day: 1,
            createdAt: DateTime(today.year, today.month, 1),
          ),
        );
      }
      await repository.registerDuePayouts(await repository.fetchWallets());
      return (await repository.fetchWallets()).single;
    }

    test('grava tudo e avisa uma vez só', () async {
      final changes = DataChanges();
      repository = WalletRepository(database, changes);
      final wallet = await seedWithTwoPayouts();
      final kept = wallet.payouts.last;
      final removed = wallet.payouts.first;

      var published = 0;
      changes.addListener(() => published++);
      await repository.saveWalletWithPayouts(
        wallet.copyWith(name: 'Salário CLT'),
        payouts: [
          kept.copyWith(amount: 3000),
          Payout(
            walletId: 0,
            label: 'Bônus',
            amount: 400,
            day: 20,
            createdAt: DateTime.now(),
          ),
        ],
        removedPayoutIds: [removed.id!],
      );

      final saved = (await repository.fetchWallets()).single;
      expect(published, 1);
      expect(saved.name, 'Salário CLT');
      expect(saved.payouts.map((payout) => payout.label), ['Salário', 'Bônus']);
      expect(saved.payouts.first.amount, 3000);
      expect(
        (await repository.fetchReceipts()).where(
          (receipt) => receipt.payoutId == removed.id,
        ),
        isEmpty,
      );
    });

    test('a carteira nova recebe o calendário com o id dela', () async {
      final walletId = await repository.saveWalletWithPayouts(
        Wallet(
          name: 'Vale',
          kind: WalletKind.benefit,
          colorIndex: 1,
          createdAt: DateTime.now(),
        ),
        payouts: [
          Payout(
            walletId: 0,
            label: 'Mensal',
            amount: 600,
            day: 1,
            createdAt: DateTime.now(),
          ),
        ],
      );

      final saved = (await repository.fetchWallets()).single;
      expect(saved.id, walletId);
      expect(saved.payouts.single.walletId, walletId);
    });
  });
}
