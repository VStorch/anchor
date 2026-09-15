import 'package:anchor/core/database/app_database.dart';
import 'package:anchor/core/state/data_changes.dart';
import 'package:anchor/core/state/month_selection.dart';
import 'package:anchor/core/utils/moment.dart';
import 'package:anchor/core/utils/month.dart';
import 'package:anchor/features/budget/services/budget_service.dart';
import 'package:anchor/features/cards/models/credit_card.dart';
import 'package:anchor/features/cards/repositories/card_repository.dart';
import 'package:anchor/features/expenses/models/expense.dart';
import 'package:anchor/features/expenses/models/expense_month.dart';
import 'package:anchor/features/expenses/models/expense_payment.dart';
import 'package:anchor/features/expenses/models/expense_type.dart';
import 'package:anchor/features/expenses/models/payable.dart';
import 'package:anchor/features/reminders/models/due_reminder.dart';
import 'package:anchor/features/expenses/repositories/expense_repository.dart';
import 'package:anchor/features/expenses/viewmodels/expenses_view_model.dart';
import 'package:anchor/features/wallets/models/balance_check.dart';
import 'package:anchor/features/wallets/models/payout.dart';
import 'package:anchor/features/wallets/models/payout_schedule.dart';
import 'package:anchor/features/wallets/models/wallet.dart';
import 'package:anchor/features/wallets/models/wallet_kind.dart';
import 'package:anchor/features/wallets/repositories/wallet_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_database.dart';

void main() {
  late AppDatabase database;
  late DataChanges changes;
  late ExpenseRepository expenses;
  late WalletRepository wallets;
  late CardRepository cards;
  late ExpensesViewModel viewModel;
  late MonthSelection selection;
  late int walletId;

  final month = Month.current();

  setUp(() async {
    database = createInMemoryDatabase();
    changes = DataChanges();
    expenses = ExpenseRepository(database, changes);
    wallets = WalletRepository(database, changes);
    cards = CardRepository(database, changes);
    walletId = await wallets.saveWallet(
      Wallet(
        name: 'Salário',
        kind: WalletKind.salary,
        colorIndex: 0,
        createdAt: DateTime.now(),
      ),
    );
    selection = MonthSelection();
    viewModel = ExpensesViewModel(
      budgetService: BudgetService(expenses, wallets, cards),
      expenseRepository: expenses,
      monthSelection: selection,
      changes: changes,
    );
  });

  tearDown(() async {
    viewModel.dispose();
    await database.close();
  });

  Future<int> saveBill(String name, double amount, {int? cardId}) async {
    await expenses.saveExpense(
      Expense(
        name: name,
        type: ExpenseType.single,
        amount: amount,
        dueDay: 10,
        startMonth: month,
        walletId: walletId,
        cardId: cardId,
        createdAt: DateTime.now(),
      ),
    );
    return (await expenses.fetchExpenses())
        .firstWhere((expense) => expense.name == name)
        .id!;
  }

  Future<void> pay(int expenseId, double amount) => expenses.savePayment(
    ExpensePayment(
      expenseId: expenseId,
      walletId: walletId,
      month: month,
      amount: amount,
      paidAt: DateTime.now(),
    ),
  );

  test('pagar a fatura lança exatamente o que falta nela', () async {
    final cardId = await cards.saveCard(
      CreditCard(
        name: 'Nubank',
        closingDay: 3,
        dueDay: 10,
        walletId: walletId,
        createdAt: DateTime.now(),
      ),
    );
    final phone = await saveBill('Celular', 100, cardId: cardId);
    await saveBill('Fone', 100, cardId: cardId);
    await pay(phone, 150);
    await viewModel.initialize();

    final invoice = viewModel.invoiceOf(cardId)!;
    expect(invoice.isPaid, isFalse);
    expect(invoice.remaining, 100);

    final paidBefore = invoice.paidAmount;
    await viewModel.payInvoice(
      invoice,
      origin: (walletId: walletId, outside: false),
      paidAt: DateTime.now(),
    );
    await viewModel.refresh();

    final paid = viewModel.invoiceOf(cardId)!;
    expect(paid.paidAmount - paidBefore, invoice.remaining);
    expect(paid.isPaid, isTrue);
    expect(viewModel.summary.totalPending, 0);
  });

  test('confirmar o valor do mês sem mudar nada não grava o mês', () async {
    final light = await saveBill('Luz', 180);
    await viewModel.initialize();

    await viewModel.setMonthAmount(viewModel.occurrenceOf(light)!, 180);

    expect(await expenses.fetchMonthAmounts(), isEmpty);
  });

  test('apagar o valor do mês volta para o valor da regra', () async {
    final light = await saveBill('Luz', 180);
    await expenses.saveMonthAmount(
      ExpenseMonth(expenseId: light, month: month, amount: 143.2),
    );
    await viewModel.initialize();

    await viewModel.setMonthAmount(viewModel.occurrenceOf(light)!, 0);
    await viewModel.refresh();

    final occurrence = viewModel.occurrenceOf(light)!;
    expect(await expenses.fetchMonthAmounts(), isEmpty);
    expect(occurrence.amount, 180);
    expect(occurrence.isPaid, isFalse);
  });

  test('valor do mês vazio numa conta sem ajuste não a quita', () async {
    final light = await saveBill('Luz', 180);
    await viewModel.initialize();

    await viewModel.setMonthAmount(viewModel.occurrenceOf(light)!, 0);
    await viewModel.refresh();

    expect(await expenses.fetchMonthAmounts(), isEmpty);
    expect(viewModel.occurrenceOf(light)!.isPaid, isFalse);
  });

  test(
    'confirmar o valor pago sem mudar nada não regrava o pagamento',
    () async {
      final light = await saveBill('Luz', 180);
      await pay(light, 80);
      await viewModel.initialize();
      final before = (await expenses.fetchPayments()).single;

      var published = 0;
      changes.addListener(() => published++);
      await viewModel.setPaidAmount(viewModel.occurrenceOf(light)!, 80);

      expect(published, 0);
      expect((await expenses.fetchPayments()).single.paidAt, before.paidAt);
    },
  );

  test('valor negativo na tabela não apaga os pagamentos nem o mês', () async {
    final light = await saveBill('Luz', 180);
    await pay(light, 80);
    await expenses.saveMonthAmount(
      ExpenseMonth(expenseId: light, month: month, amount: 150),
    );
    await viewModel.initialize();

    await viewModel.setPaidAmount(viewModel.occurrenceOf(light)!, -5);
    await viewModel.setMonthAmount(viewModel.occurrenceOf(light)!, -5);

    expect((await expenses.fetchPayments()).single.amount, 80);
    expect((await expenses.fetchMonthAmounts()).single.amount, 150);
  });

  Future<Expense> saveRecurring({
    required Month start,
    Month? end,
    int dueDay = 10,
    DateTime? createdAt,
  }) async {
    await expenses.saveExpense(
      Expense(
        name: 'Conta',
        type: ExpenseType.recurring,
        amount: 100,
        dueDay: dueDay,
        startMonth: start,
        endMonth: end,
        walletId: walletId,
        createdAt: createdAt ?? start.firstDay,
      ),
    );
    return (await expenses.fetchExpenses()).last;
  }

  Future<void> payOn(Expense expense, Month paidMonth, double amount) =>
      expenses.savePayment(
        ExpensePayment(
          expenseId: expense.id!,
          walletId: walletId,
          month: paidMonth,
          amount: amount,
          paidAt: DateTime.now(),
        ),
      );

  test('a conta do mês que vem paga hoje não desconta duas vezes depois do '
      'saldo informado', () async {
    final expense = await saveRecurring(start: month);
    selection.goToNext();
    await viewModel.initialize();
    final next = viewModel.occurrenceOf(expense.id!)!;

    final paidAt = next.suggestedPaidAt(DateTime.now());
    await viewModel.settle(
      next,
      origin: viewModel.defaultOriginFor(next),
      paidAt: paidAt,
    );
    await wallets.saveBalanceCheck(
      BalanceCheck(
        walletId: walletId,
        amount: -100,
        checkedAt: DateTime.now().add(const Duration(seconds: 1)),
      ),
    );
    await viewModel.refresh();

    expect(paidAt.isAfter(DateTime.now()), isFalse);
    expect(viewModel.snapshot.summaryFor(walletId)!.balance, -100);
  });

  test(
    'o valor pago da tabela usa a data escolhida no primeiro pagamento',
    () async {
      final light = await saveBill('Luz', 180);
      await viewModel.initialize();
      final chosen = DateTime(month.year, month.month, 1, 12);

      await viewModel.setPaidAmount(
        viewModel.occurrenceOf(light)!,
        100,
        paidAt: chosen,
      );
      await viewModel.refresh();
      await viewModel.setPaidAmount(
        viewModel.occurrenceOf(light)!,
        150,
        paidAt: DateTime.now(),
      );

      expect((await expenses.fetchPayments()).single.paidAt, chosen);
      expect((await expenses.fetchPayments()).single.amount, 150);
    },
  );

  group('ocorrência fora da regra', () {
    test('o parcial adiantado não deve nada, nem lembra, nem aceita valor do '
        'mês', () async {
      final expense = await saveRecurring(
        start: month,
        dueDay: 28,
        createdAt: DateTime.now(),
      );
      await payOn(expense, month.next, 50);
      await viewModel.initialize();
      await viewModel.endRecurringExpense(expense, month);

      selection.goToNext();
      await viewModel.refresh();
      final off = viewModel.occurrenceOf(expense.id!)!;
      expect(off.offRule, isTrue);
      expect(off.remaining, 0);
      expect(off.isOverdue, isFalse);

      await viewModel.setMonthAmount(off, 100);
      await viewModel.refresh();

      expect(await expenses.fetchMonthAmounts(), isEmpty);
      expect(viewModel.summary.totalPending, 0);
      expect(
        DueReminder.plan(viewModel.summary.payables, now: DateTime.now()),
        isEmpty,
      );
    });

    test(
      'com o início movido para depois, não encerra antes do início',
      () async {
        final expense = await saveRecurring(
          start: month,
          createdAt: DateTime.now(),
        );
        await payOn(expense, month, 100);
        await expenses.saveExpense(
          expense.copyWith(startMonth: month.addMonths(2)),
        );
        await viewModel.initialize();
        final off = viewModel.occurrenceOf(expense.id!)!;
        expect(off.offRule, isTrue);
        expect(off.expense.canEndIn(viewModel.month), isFalse);

        await viewModel.endRecurringExpense(off.expense, viewModel.month);

        expect((await expenses.fetchExpenses()).single.endMonth, isNull);
      },
    );

    test('depois do fim, encerrar não reabre os meses sem pagamento', () async {
      final start = month.addMonths(-2);
      final expense = await saveRecurring(start: start, end: start);
      await payOn(expense, month, 100);
      await viewModel.initialize();
      final off = viewModel.occurrenceOf(expense.id!)!;
      expect(off.offRule, isTrue);
      expect(off.expense.canEndIn(month), isFalse);

      await viewModel.endRecurringExpense(off.expense, month);

      expect((await expenses.fetchExpenses()).single.endMonth, start);
    });
  });

  group('saldo informado depois do vencimento', () {
    const september = Month(2026, 9);
    final checkedAt = DateTime(2026, 9, 13, 18);
    final afterCheck = DateTime(2026, 9, 13, 19);

    Future<int> saveMonthly(String name, double amount, int dueDay) async {
      await expenses.saveExpense(
        Expense(
          name: name,
          type: ExpenseType.recurring,
          amount: amount,
          dueDay: dueDay,
          startMonth: september,
          walletId: walletId,
          createdAt: DateTime(2026, 9, 1),
        ),
      );
      return (await expenses.fetchExpenses())
          .firstWhere((expense) => expense.name == name)
          .id!;
    }

    Future<void> openSeptemberWithCheck() async {
      await wallets.saveBalanceCheck(
        BalanceCheck(walletId: walletId, amount: 850, checkedAt: checkedAt),
      );
      viewModel.dispose();
      final selection = MonthSelection()..current = september;
      viewModel = ExpensesViewModel(
        budgetService: BudgetService(expenses, wallets, cards),
        expenseRepository: expenses,
        monthSelection: selection,
        changes: changes,
      );
      await viewModel.initialize();
    }

    double balance() => viewModel.snapshot.summaryFor(walletId)!.balance;

    test('pergunta quando a conta venceu antes do saldo informado', () async {
      final rent = await saveMonthly('Aluguel', 1100, 5);
      final gym = await saveMonthly('Academia', 120, 20);
      await openSeptemberWithCheck();

      final check = viewModel.checkCoveringDue(
        viewModel.occurrenceOf(rent)!,
        walletId,
      );
      expect(check?.amount, 850);
      expect(
        viewModel.checkCoveringDue(viewModel.occurrenceOf(gym)!, walletId),
        isNull,
      );
      expect(
        viewModel.checkCoveringDue(viewModel.occurrenceOf(rent)!, null),
        isNull,
      );
    });

    test('a conta com pagamento lançado não pergunta de novo', () async {
      final rent = await saveMonthly('Aluguel', 1100, 5);
      await openSeptemberWithCheck();
      await viewModel.savePaymentLine(
        viewModel.occurrenceOf(rent)!,
        origin: (walletId: walletId, outside: false),
        amount: 100,
        paidAt: afterCheck,
      );
      await viewModel.refresh();

      expect(
        viewModel.checkCoveringDue(viewModel.occurrenceOf(rent)!, walletId),
        isNull,
      );
    });

    test('o pagamento já descontado fica antes do saldo informado', () async {
      final rent = await saveMonthly('Aluguel', 1100, 5);
      await openSeptemberWithCheck();
      final occurrence = viewModel.occurrenceOf(rent)!;
      final check = viewModel.checkCoveringDue(occurrence, walletId)!;

      expect(
        viewModel.paidBeforeCheck(occurrence, check, now: afterCheck),
        DateTime(2026, 9, 5, 12),
      );

      final sameDay = BalanceCheck(
        walletId: walletId,
        amount: 850,
        checkedAt: DateTime(2026, 9, 5, 9),
      );
      expect(
        viewModel.paidBeforeCheck(occurrence, sameDay, now: afterCheck),
        DateTime(2026, 9, 5, 8, 59, 59),
      );
    });

    test('responder "já estava descontado" mantém o saldo em 850', () async {
      final rent = await saveMonthly('Aluguel', 1100, 5);
      await openSeptemberWithCheck();
      final occurrence = viewModel.occurrenceOf(rent)!;
      final check = viewModel.checkCoveringDue(occurrence, walletId)!;

      await viewModel.settle(
        occurrence,
        origin: viewModel.defaultOriginFor(occurrence),
        paidAt: viewModel.paidBeforeCheck(occurrence, check, now: afterCheck),
      );
      await viewModel.refresh();

      expect(viewModel.occurrenceOf(rent)!.isPaid, isTrue);
      expect(balance(), 850);
    });

    test('responder "paguei agora" desconta do saldo informado', () async {
      final rent = await saveMonthly('Aluguel', 1100, 5);
      await openSeptemberWithCheck();

      await viewModel.settle(
        viewModel.occurrenceOf(rent)!,
        origin: (walletId: walletId, outside: false),
        paidAt: afterCheck,
      );
      await viewModel.refresh();

      expect(balance(), -250);
    });

    test(
      'cenário da usuária: aluguel no dia 10 e academia com outro dinheiro',
      () async {
        await wallets.savePayout(
          Payout(
            walletId: walletId,
            label: 'Salário',
            amount: 3200,
            day: 5,
            schedule: PayoutSchedule.businessDay,
            createdAt: DateTime(2026, 9, 1),
          ),
        );
        final rent = await saveMonthly('Aluguel', 1100, 10);
        final gym = await saveMonthly('Academia', 120, 15);
        await openSeptemberWithCheck();
        expect(balance(), 850);

        await viewModel.savePaymentLine(
          viewModel.occurrenceOf(rent)!,
          origin: (walletId: walletId, outside: false),
          amount: 1100,
          paidAt: stampFor(DateTime(2026, 9, 10), now: afterCheck),
        );
        await viewModel.settle(
          viewModel.occurrenceOf(gym)!,
          origin: (walletId: null, outside: true),
          paidAt: afterCheck,
        );
        await viewModel.refresh();

        final gymOccurrence = viewModel.occurrenceOf(gym)!;
        expect(viewModel.occurrenceOf(rent)!.isPaid, isTrue);
        expect(gymOccurrence.isPaid, isTrue);
        expect(gymOccurrence.payments.single.settledOutside, isTrue);
        expect(balance(), 850);
        expect(viewModel.summary.totalPaid, 1220);
        expect(viewModel.summary.totalSpent, 1100);
      },
    );
  });
}
