import 'package:anchor/core/database/app_database.dart';
import 'package:anchor/core/state/data_changes.dart';
import 'package:anchor/core/utils/month.dart';
import 'package:anchor/features/budget/services/budget_service.dart';
import 'package:anchor/features/wallets/models/outflow.dart';
import 'package:anchor/features/expenses/models/expense_payment.dart';
import 'package:anchor/features/cards/models/credit_card.dart';
import 'package:anchor/features/cards/repositories/card_repository.dart';
import 'package:anchor/features/expenses/models/expense.dart';
import 'package:anchor/features/expenses/models/expense_type.dart';
import 'package:anchor/features/expenses/repositories/expense_repository.dart';
import 'package:anchor/features/wallets/models/balance_check.dart';
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
      expect(snapshot.forecast!.freeMoney.toPay, 464.90);
      expect(snapshot.forecast!.freeMoney.endBalance, 385.10);
      expect(snapshot.forecast!.benefits.endBalance, 162.70);
    });

    test(
      'em outubro soma o salário e o vale previstos e desconta as contas',
      () async {
        await seedSeptember();

        final snapshot = await service.loadSnapshot(october, now: now);
        final forecast = snapshot.forecast!;

        expect(snapshot.walletsBalance, 1012.70);
        expect(forecast.freeMoney.toReceive, 3200);
        expect(forecast.benefits.toReceive, 600);
        expect(forecast.freeMoney.toPay, 929.80);
        expect(forecast.unassignedToPay, 300);
        expect(forecast.wallets.first.endBalance, 850 + 3200 - 929.80);
        expect(forecast.freeMoney.endBalance, 2820.20);
        expect(forecast.benefits.endBalance, 762.70);
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
      expect(snapshot.forecast!.freeMoney.toReceive, 6000);
    });
  });

  group('salário que cai depois do saldo informado', () {
    final checkedAt = DateTime(2026, 9, 14, 13);
    final later = DateTime(2026, 9, 14, 18);

    Future<(int, Receipt)> seedSalaryOnThe8th() async {
      final id = await walletWith(
        name: 'Salário',
        kind: WalletKind.salary,
        payout: Payout(
          walletId: 0,
          label: 'Mensal',
          amount: 3000,
          day: 8,
          createdAt: DateTime(2026, 9),
        ),
      );
      await wallets.registerDuePayouts(
        await wallets.fetchWallets(),
        now: checkedAt,
      );
      return (id, (await wallets.fetchReceipts()).single);
    }

    Future<double> balanceOf(int walletId) async => (await service.loadSnapshot(
      september,
      now: later,
    )).summaryFor(walletId)!.balance;

    test('desmarcado no saldo e confirmado com a data do calendário, '
        'entra no saldo', () async {
      final (id, salary) = await seedSalaryOnThe8th();
      await wallets.saveBalanceCheck(
        BalanceCheck(walletId: id, amount: 100, checkedAt: checkedAt),
        leftPending: [salary],
      );

      final pending = (await wallets.fetchReceipts()).single;
      await wallets.saveReceipt(
        pending.copyWith(status: ReceiptStatus.confirmed),
      );

      expect(await balanceOf(id), 3100);
    });

    test('desmarcado no saldo e confirmado com a data de hoje, entra no '
        'saldo', () async {
      final (id, salary) = await seedSalaryOnThe8th();
      await wallets.saveBalanceCheck(
        BalanceCheck(walletId: id, amount: 100, checkedAt: checkedAt),
        leftPending: [salary],
      );

      final pending = (await wallets.fetchReceipts()).single;
      await wallets.saveReceipt(
        pending.copyWith(status: ReceiptStatus.confirmed, receivedAt: later),
      );

      expect(await balanceOf(id), 3100);
    });

    test('marcado como já caiu no saldo, não soma de novo', () async {
      final (id, salary) = await seedSalaryOnThe8th();
      await wallets.saveBalanceCheck(
        BalanceCheck(walletId: id, amount: 100, checkedAt: checkedAt),
        confirm: [salary],
      );

      expect(await balanceOf(id), 100);
    });

    test('o saldo informado sem a lista (como o da versão 8) já continha o '
        'previsto de antes dele', () async {
      final (id, salary) = await seedSalaryOnThe8th();
      await wallets.saveBalanceCheck(
        BalanceCheck(walletId: id, amount: 100, checkedAt: checkedAt),
      );
      await wallets.saveReceipt(
        salary.copyWith(status: ReceiptStatus.confirmed),
      );

      expect(await balanceOf(id), 100);
    });

    test(
      'um saldo informado depois não herda a pendência do anterior',
      () async {
        final (id, salary) = await seedSalaryOnThe8th();
        await wallets.saveBalanceCheck(
          BalanceCheck(walletId: id, amount: 100, checkedAt: checkedAt),
          leftPending: [salary],
        );
        await wallets.saveBalanceCheck(
          BalanceCheck(walletId: id, amount: 3100, checkedAt: later),
          confirm: [(await wallets.fetchReceipts()).single],
        );

        expect(await balanceOf(id), 3100);
      },
    );
  });

  group('previstos de meses que já terminaram', () {
    test('valem como recebidos no saldo e no Entrou', () async {
      final id = await wallets.saveWallet(
        Wallet(
          name: 'Salário',
          kind: WalletKind.salary,
          colorIndex: 0,
          createdAt: DateTime(2026, 7),
        ),
      );
      await wallets.savePayout(
        Payout(
          walletId: id,
          label: 'Mensal',
          amount: 3000,
          day: 5,
          createdAt: DateTime(2026, 7),
        ),
      );
      await wallets.registerDuePayouts(
        await wallets.fetchWallets(),
        now: DateTime(2026, 8, 20),
      );

      final august = await service.loadSnapshot(const Month(2026, 8), now: now);

      expect(august.summaryFor(id)!.balance, 6000);
      expect(august.summaryFor(id)!.receivedInMonth, 3000);
      expect(august.summary.totalReceived, 3000);
      expect(august.awaitingConfirmation, 3000);
    });
  });

  test('excluir a carteira com entradas, gastos, saldo, cartão e contas '
      'deixa as contas pagas e nenhum dinheiro para trás', () async {
    final changes = DataChanges();
    final cards = CardRepository(database, changes);
    final id = await wallets.saveWallet(
      Wallet(
        name: 'Salário',
        kind: WalletKind.salary,
        colorIndex: 0,
        createdAt: DateTime(2026, 9),
      ),
    );
    await wallets.saveReceipt(
      Receipt(
        walletId: id,
        month: september,
        amount: 1000,
        receivedAt: DateTime(2026, 9, 1, 12),
      ),
    );
    await wallets.saveOutflow(
      Outflow(
        walletId: id,
        description: 'Mercado',
        amount: 30,
        spentAt: DateTime(2026, 9, 12, 12),
      ),
    );
    await wallets.saveBalanceCheck(
      BalanceCheck(walletId: id, amount: 500, checkedAt: now),
    );
    final cardId = await cards.saveCard(
      CreditCard(
        name: 'Nubank',
        closingDay: 3,
        dueDay: 10,
        walletId: id,
        createdAt: DateTime(2026, 9),
      ),
    );
    await expenses.saveExpense(
      Expense(
        name: 'Aluguel',
        type: ExpenseType.recurring,
        amount: 100,
        dueDay: 10,
        startMonth: september,
        walletId: id,
        createdAt: DateTime(2026, 9),
      ),
    );
    final rent = (await expenses.fetchExpenses()).single;
    await expenses.savePayment(
      ExpensePayment(
        expenseId: rent.id!,
        walletId: id,
        month: september,
        amount: 100,
        paidAt: DateTime(2026, 9, 10, 12),
      ),
    );

    final before = await service.loadSnapshot(september, now: now);
    final impact = before.deletionImpactOf(id);
    expect(
      [
        impact.receipts,
        impact.outflows,
        impact.checks,
        impact.paidBills,
        impact.plannedBills,
        impact.cards,
      ],
      [1, 1, 1, 1, 1, 1],
    );

    await wallets.deleteWallet(id);
    final after = await service.loadSnapshot(september, now: now);

    final occurrence = after.summary.occurrenceOf(rent.id!)!;
    expect(occurrence.isPaid, isTrue);
    expect(occurrence.payments.single.settledOutside, isTrue);
    expect(after.summary.totalSpent, 0);
    expect(after.summary.totalReceived, 0);
    expect(after.checks, isEmpty);
    expect(after.outflows, isEmpty);
    expect(after.expenses.single.walletId, isNull);
    expect(after.cards.single.walletId, isNull);
    expect(after.cardById(cardId), isNotNull);
  });
}
