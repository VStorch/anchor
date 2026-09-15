import 'package:anchor/core/database/app_database.dart';
import 'package:anchor/core/state/data_changes.dart';
import 'package:anchor/core/utils/month.dart';
import 'package:anchor/features/budget/services/budget_service.dart';
import 'package:anchor/features/cards/repositories/card_repository.dart';
import 'package:anchor/features/expenses/repositories/expense_repository.dart';
import 'package:anchor/features/onboarding/models/onboarding_draft.dart';
import 'package:anchor/features/onboarding/services/onboarding_service.dart';
import 'package:anchor/features/wallets/models/payout_schedule.dart';
import 'package:anchor/features/wallets/models/receipt_status.dart';
import 'package:anchor/features/wallets/models/wallet_kind.dart';
import 'package:anchor/features/wallets/repositories/wallet_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_database.dart';

void main() {
  const september = Month(2026, 9);
  final now = DateTime(2026, 9, 15, 10);

  late AppDatabase database;
  late DataChanges changes;
  late WalletRepository wallets;
  late ExpenseRepository expenses;
  late CardRepository cards;
  late BudgetService budget;
  late OnboardingService service;

  setUp(() {
    database = createInMemoryDatabase();
    changes = DataChanges();
    wallets = WalletRepository(database, changes);
    expenses = ExpenseRepository(database, changes);
    cards = CardRepository(database, changes);
    budget = BudgetService(expenses, wallets, cards);
    service = OnboardingService(
      wallets: wallets,
      expenses: expenses,
      cards: cards,
      budget: budget,
      changes: changes,
    );
  });

  tearDown(() => database.close());

  IncomeDraft salary({double? balance, bool? arrived}) =>
      IncomeDraft(kind: WalletKind.salary, name: 'Salário')
        ..amount = 3200
        ..schedule = PayoutSchedule.businessDay
        ..day = 5
        ..balanceToday = balance
        ..arrived = arrived;

  IncomeDraft voucher({double? balance, bool? arrived}) =>
      IncomeDraft(kind: WalletKind.benefit, name: 'VR')
        ..amount = 600
        ..day = 1
        ..balanceToday = balance
        ..arrived = arrived;

  BillDraft bill(String name, double amount, int day, {bool paid = true}) =>
      BillDraft(name: name, isSuggestion: true)
        ..amount = amount
        ..dueDay = day
        ..paidThisMonth = paid;

  InstallmentDraft fridge() => InstallmentDraft()
    ..name = 'Geladeira'
    ..amount = 180
    ..currentNumber = 4
    ..total = 10
    ..dueDay = 5;

  OnboardingDraft fullDraft({bool voucherArrived = true}) {
    final salaryDraft = salary(balance: 850, arrived: true);
    return OnboardingDraft(
      incomes: [
        salaryDraft,
        voucher(balance: 210, arrived: voucherArrived),
      ],
      bills: [bill('Aluguel', 1100, 10), bill('Internet', 99.90, 15)],
      installments: [fridge()],
      card: CardDraft(payer: salaryDraft)
        ..name = 'Nubank'
        ..closingDay = 3
        ..dueDay = 10,
    );
  }

  test('só pede a configuração a quem não tem nada cadastrado', () async {
    expect(await service.needsOnboarding(now), isTrue);

    await service.apply(
      OnboardingDraft(bills: [bill('Luz', 150, 20)]),
      now: now,
    );

    expect(await service.needsOnboarding(now), isFalse);
  });

  test(
    'o saldo de hoje é o que a pessoa digitou, com tudo cadastrado',
    () async {
      var notified = 0;
      changes.addListener(() => notified++);

      await service.apply(fullDraft(), now: now);

      expect(notified, 1);

      final snapshot = await budget.loadSnapshot(september, now: now);
      expect(snapshot.walletsBalance, 1060);
      expect(snapshot.wallets.map((wallet) => wallet.name), ['Salário', 'VR']);

      final salaryWallet = snapshot.wallets.firstWhere(
        (wallet) => wallet.kind == WalletKind.salary,
      );
      expect(
        salaryWallet.payouts.single.dateIn(september),
        DateTime(2026, 9, 8),
      );

      final card = snapshot.cards.single;
      expect(card.name, 'Nubank');
      expect(card.walletId, salaryWallet.id);

      final occurrences = {
        for (final occurrence in snapshot.summary.occurrences)
          occurrence.name: occurrence,
      };
      expect(occurrences['Aluguel']!.isPaid, isTrue);
      expect(occurrences['Aluguel']!.payments.single.walletId, salaryWallet.id);
      expect(occurrences['Internet']!.isPaid, isFalse);
      expect(occurrences['Geladeira']!.installmentNumber, 4);
      expect(occurrences['Geladeira']!.isPaid, isTrue);
      expect(snapshot.awaitingConfirmation, 0);
    },
  );

  test('a parcela 4 de 10 projeta da 4 à 10', () async {
    await service.apply(OnboardingDraft(installments: [fridge()]), now: now);

    final expense = (await expenses.fetchExpenses()).single;
    expect(expense.settledInstallments, 3);
    expect(expense.occurrenceIn(september)!.installmentNumber, 4);
    expect(expense.occurrenceIn(september.addMonths(6))!.installmentNumber, 10);
    expect(expense.occurrenceIn(september.addMonths(7)), isNull);
  });

  test('a conta já paga fica antes do saldo informado', () async {
    await service.apply(fullDraft(), now: now);

    final rent = (await expenses.fetchExpenses()).firstWhere(
      (expense) => expense.name == 'Aluguel',
    );
    final payment = (await expenses.fetchPayments()).firstWhere(
      (payment) => payment.expenseId == rent.id,
    );
    expect(payment.paidAt, DateTime(2026, 9, 10, 12));
    expect(payment.month, september);
  });

  test('o salário que já caiu é confirmado uma vez, dentro do saldo', () async {
    await service.apply(fullDraft(), now: now);
    await budget.loadSnapshot(september, now: now);

    final receipts = await wallets.fetchReceipts();
    expect(receipts, hasLength(2));
    expect(receipts.every((receipt) => receipt.isConfirmed), isTrue);
    expect(receipts.every((receipt) => receipt.month == september), isTrue);
  });

  test('o que ainda não caiu fica a confirmar e entra quando chega', () async {
    await service.apply(fullDraft(voucherArrived: false), now: now);

    final check = (await wallets.fetchBalanceChecks()).firstWhere(
      (check) => check.amount == 210,
    );
    final pending = (await wallets.fetchReceipts()).singleWhere(
      (receipt) => receipt.isPredicted,
    );
    expect(pending.amount, 600);
    expect(pending.pendingAtCheckId, check.id);

    var snapshot = await budget.loadSnapshot(september, now: now);
    expect(snapshot.walletsBalance, 1060);
    expect(snapshot.awaitingConfirmation, 600);

    await wallets.saveReceipt(
      pending.copyWith(status: ReceiptStatus.confirmed),
    );
    snapshot = await budget.loadSnapshot(september, now: now);
    expect(snapshot.walletsBalance, 1660);
  });

  test(
    'sem saldo informado, a conta já paga sai do saldo e o salário fica a confirmar',
    () async {
      await service.apply(
        OnboardingDraft(
          incomes: [salary()],
          bills: [bill('Aluguel', 1100, 10)],
        ),
        now: now,
      );

      final snapshot = await budget.loadSnapshot(september, now: now);
      expect(await wallets.fetchBalanceChecks(), isEmpty);
      expect(snapshot.awaitingConfirmation, 3200);
      expect(snapshot.walletsBalance, -1100);
    },
  );

  test('a conta que ainda não venceu não é marcada como paga', () async {
    await service.apply(
      OnboardingDraft(
        incomes: [salary(balance: 850, arrived: true)],
        bills: [bill('Academia', 120, 20)],
      ),
      now: now,
    );

    expect(await expenses.fetchPayments(), isEmpty);
  });
}
