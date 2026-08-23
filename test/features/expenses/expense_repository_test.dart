import 'package:anchor/core/database/app_database.dart';
import 'package:anchor/core/state/data_changes.dart';
import 'package:anchor/core/utils/month.dart';
import 'package:anchor/features/expenses/models/expense.dart';
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

  test('mantém um único pagamento por mês da mesma despesa', () async {
    final expense = await saveInstallment();

    await repository.savePayment(
      ExpensePayment(
        expenseId: expense.id!,
        month: const Month(2026, 8),
        amount: 250,
        paidAt: DateTime(2026, 8, 12),
      ),
    );
    await repository.savePayment(
      ExpensePayment(
        expenseId: expense.id!,
        month: const Month(2026, 8),
        amount: 300,
        paidAt: DateTime(2026, 8, 13),
      ),
    );

    final payments = await repository.fetchPayments();

    expect(payments, hasLength(1));
    expect(payments.single.amount, 300);
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
        ),
      );
    }

    await repository.deletePayment(expense.id!, const Month(2026, 8));
    final payments = await repository.fetchPayments();

    expect(payments, hasLength(1));
    expect(payments.single.month, const Month(2026, 9));
  });

  test('excluir a despesa apaga o histórico de pagamentos', () async {
    final expense = await saveInstallment();
    await repository.savePayment(
      ExpensePayment(
        expenseId: expense.id!,
        month: const Month(2026, 8),
        amount: 250,
        paidAt: DateTime(2026, 8, 12),
      ),
    );

    await repository.deleteExpense(expense.id!);

    expect(await repository.fetchExpenses(), isEmpty);
    expect(await repository.fetchPayments(), isEmpty);
  });
}
