import 'package:anchor/core/database/app_database.dart';
import 'package:anchor/core/state/data_changes.dart';
import 'package:anchor/core/utils/month.dart';
import 'package:anchor/features/expenses/models/expense.dart';
import 'package:anchor/features/expenses/models/expense_payment.dart';
import 'package:anchor/features/expenses/models/expense_type.dart';
import 'package:anchor/features/expenses/repositories/expense_repository.dart';
import 'package:anchor/features/expenses/viewmodels/expense_form_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_database.dart';

void main() {
  late AppDatabase database;
  late ExpenseRepository repository;

  const august = Month(2026, 8);

  final gym = Expense(
    id: 1,
    name: 'Academia',
    type: ExpenseType.recurring,
    amount: 120,
    dueDay: 10,
    startMonth: august,
    endMonth: const Month(2026, 9),
    createdAt: DateTime(2026, 8),
  );

  ExpensePayment paidIn(Month month) => ExpensePayment(
    expenseId: 1,
    month: month,
    amount: 120,
    paidAt: month.dayOf(10),
    settledOutside: true,
  );

  setUp(() {
    database = createInMemoryDatabase();
    repository = ExpenseRepository(database, DataChanges());
  });

  tearDown(() => database.close());

  ExpenseFormViewModel edit(List<ExpensePayment> payments) =>
      ExpenseFormViewModel(
        repository: repository,
        referenceMonth: august,
        expense: gym,
        payments: payments,
      );

  test('o fim antes do início invalida o formulário', () {
    final form = edit(const [])..setStartMonth(const Month(2026, 10));

    expect(form.endsBeforeStart, isTrue);
    expect(form.isValid, isFalse);

    form.setEndMonth(null);
    expect(form.endsBeforeStart, isFalse);
    expect(form.isValid, isTrue);
  });

  test('trocar para outro tipo limpa o mês final', () {
    final form = edit(const [])..setType(ExpenseType.single);

    expect(form.endMonth, isNull);
    expect(form.endsBeforeStart, isFalse);
  });

  test('conta só os meses pagos que a mudança deixa de fora', () {
    final form = edit([
      paidIn(august),
      paidIn(const Month(2026, 9)),
      paidIn(const Month(2026, 10)),
    ]);

    expect(form.monthsLeftOffRule, isEmpty);

    form.setEndMonth(august);
    expect(form.monthsLeftOffRule, {const Month(2026, 9)});
  });
}
