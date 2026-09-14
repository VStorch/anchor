import 'package:anchor/core/database/app_database.dart';
import 'package:anchor/core/state/data_changes.dart';
import 'package:anchor/core/state/month_selection.dart';
import 'package:anchor/core/utils/month.dart';
import 'package:anchor/features/budget/services/budget_service.dart';
import 'package:anchor/features/cards/models/credit_card.dart';
import 'package:anchor/features/cards/repositories/card_repository.dart';
import 'package:anchor/features/expenses/models/expense.dart';
import 'package:anchor/features/expenses/models/expense_month.dart';
import 'package:anchor/features/expenses/models/expense_payment.dart';
import 'package:anchor/features/expenses/models/expense_type.dart';
import 'package:anchor/features/expenses/repositories/expense_repository.dart';
import 'package:anchor/features/expenses/viewmodels/expenses_view_model.dart';
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
    viewModel = ExpensesViewModel(
      budgetService: BudgetService(expenses, wallets, cards),
      expenseRepository: expenses,
      monthSelection: MonthSelection(),
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
    await viewModel.payInvoice(invoice, walletId: walletId);
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
}
