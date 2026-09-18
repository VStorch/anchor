import 'package:anchor/core/database/app_database.dart';
import 'package:anchor/core/state/data_changes.dart';
import 'package:anchor/core/utils/month.dart';
import 'package:anchor/features/expenses/models/expense.dart';
import 'package:anchor/features/expenses/models/expense_month.dart';
import 'package:anchor/features/expenses/models/expense_payment.dart';
import 'package:anchor/features/expenses/models/expense_type.dart';
import 'package:anchor/features/expenses/repositories/expense_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_database.dart';

void main() {
  late AppDatabase database;
  late ExpenseRepository repository;

  setUp(() {
    database = createInMemoryDatabase();
    repository = ExpenseRepository(database, DataChanges());
  });

  tearDown(() => database.close());

  Future<Expense> saveInstallment() async {
    await repository.saveExpense(
      Expense(
        name: 'Geladeira',
        type: ExpenseType.installment,
        amount: 250,
        dueDay: 12,
        startMonth: const Month(2026, 8),
        totalInstallments: 12,
        settledInstallments: 5,
        createdAt: DateTime(2026, 8),
      ),
    );
    return (await repository.fetchExpenses()).single;
  }

  test('preserva o parcelamento em andamento ao salvar e reler', () async {
    final expense = await saveInstallment();

    expect(expense.type, ExpenseType.installment);
    expect(expense.totalInstallments, 12);
    expect(expense.settledInstallments, 5);
    expect(expense.remainingInstallments, 7);
    expect(expense.startMonth, const Month(2026, 8));
  });

  test(
    'guarda vários pagamentos do mesmo mês em carteiras diferentes',
    () async {
      final expense = await saveInstallment();

      await repository.savePayment(
        ExpensePayment(
          expenseId: expense.id!,
          month: const Month(2026, 8),
          amount: 150,
          paidAt: DateTime(2026, 8, 12),
          settledOutside: true,
        ),
      );
      await repository.savePayment(
        ExpensePayment(
          expenseId: expense.id!,
          month: const Month(2026, 8),
          amount: 100,
          paidAt: DateTime(2026, 8, 13),
          settledOutside: true,
        ),
      );

      final payments = await repository.fetchPayments();

      expect(payments, hasLength(2));
      expect(payments.fold<double>(0, (total, p) => total + p.amount), 250);
    },
  );

  test(
    'pagar fechando o mês grava pagamento e valor do mês de uma vez',
    () async {
      final changes = DataChanges();
      final repository = ExpenseRepository(database, changes);
      final expense = await saveInstallment();
      var notified = 0;
      changes.addListener(() => notified++);
      final month = expense.startMonth;

      await repository.savePaymentClosingMonth(
        ExpensePayment(
          expenseId: expense.id!,
          walletId: null,
          settledOutside: true,
          month: month,
          amount: 237.52,
          paidAt: month.dayOf(12),
        ),
        ExpenseMonth(expenseId: expense.id!, month: month, amount: 237.52),
      );

      expect(notified, 1);
      expect((await repository.fetchPayments()).single.amount, 237.52);
      expect((await repository.fetchMonthAmounts()).single.amount, 237.52);
    },
  );

  test('editar um pagamento existente não cria linha nova', () async {
    final expense = await saveInstallment();
    await repository.savePayment(
      ExpensePayment(
        expenseId: expense.id!,
        month: const Month(2026, 8),
        amount: 150,
        paidAt: DateTime(2026, 8, 12),
        settledOutside: true,
      ),
    );

    final saved = (await repository.fetchPayments()).single;
    await repository.savePayment(
      ExpensePayment(
        id: saved.id,
        expenseId: expense.id!,
        month: const Month(2026, 8),
        amount: 200,
        paidAt: saved.paidAt,
        settledOutside: true,
      ),
    );

    final payments = await repository.fetchPayments();

    expect(payments, hasLength(1));
    expect(payments.single.amount, 200);
  });

  test('o valor do mês sobrescreve o anterior e volta ao ser limpo', () async {
    final expense = await saveInstallment();

    await repository.saveMonthAmount(
      ExpenseMonth(
        expenseId: expense.id!,
        month: const Month(2026, 8),
        amount: 300,
      ),
    );
    await repository.saveMonthAmount(
      ExpenseMonth(
        expenseId: expense.id!,
        month: const Month(2026, 8),
        amount: 280,
      ),
    );

    expect(await repository.fetchMonthAmounts(), hasLength(1));
    expect((await repository.fetchMonthAmounts()).single.amount, 280);

    await repository.clearMonthAmount(expense.id!, const Month(2026, 8));

    expect(await repository.fetchMonthAmounts(), isEmpty);
  });

  test('desfazer o pagamento remove apenas o mês informado', () async {
    final expense = await saveInstallment();

    for (final month in [const Month(2026, 8), const Month(2026, 9)]) {
      await repository.savePayment(
        ExpensePayment(
          expenseId: expense.id!,
          month: month,
          amount: 250,
          paidAt: DateTime(2026, 8, 12),
          settledOutside: true,
        ),
      );
    }

    await repository.deletePaymentsOf(expense.id!, const Month(2026, 8));
    final payments = await repository.fetchPayments();

    expect(payments, hasLength(1));
    expect(payments.single.month, const Month(2026, 9));
  });

  test('editar a despesa preserva os pagamentos e o valor do mês', () async {
    final expense = await saveInstallment();
    await repository.savePayment(
      ExpensePayment(
        expenseId: expense.id!,
        month: const Month(2026, 8),
        amount: 250,
        paidAt: DateTime(2026, 8, 12),
        settledOutside: true,
      ),
    );
    await repository.saveMonthAmount(
      ExpenseMonth(
        expenseId: expense.id!,
        month: const Month(2026, 8),
        amount: 260,
      ),
    );

    await repository.saveExpense(expense.copyWith(name: 'Geladeira nova'));

    expect((await repository.fetchExpenses()).single.name, 'Geladeira nova');
    expect(await repository.fetchPayments(), hasLength(1));
    expect(await repository.fetchMonthAmounts(), hasLength(1));
  });

  test('excluir a despesa apaga o histórico de pagamentos', () async {
    final expense = await saveInstallment();
    await repository.savePayment(
      ExpensePayment(
        expenseId: expense.id!,
        month: const Month(2026, 8),
        amount: 250,
        paidAt: DateTime(2026, 8, 12),
        settledOutside: true,
      ),
    );

    await repository.deleteExpense(expense.id!);

    expect(await repository.fetchExpenses(), isEmpty);
    expect(await repository.fetchPayments(), isEmpty);
  });

  test('excluir a despesa apaga o valor personalizado do mês', () async {
    final expense = await saveInstallment();
    await repository.saveMonthAmount(
      ExpenseMonth(
        expenseId: expense.id!,
        month: const Month(2026, 8),
        amount: 300,
      ),
    );

    await repository.deleteExpense(expense.id!);

    expect(await repository.fetchMonthAmounts(), isEmpty);
  });
}
