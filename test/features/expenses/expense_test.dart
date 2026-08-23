import 'package:anchor/core/utils/month.dart';
import 'package:anchor/features/expenses/models/expense.dart';
import 'package:anchor/features/expenses/models/expense_type.dart';
import 'package:flutter_test/flutter_test.dart';

Expense buildExpense({
  required ExpenseType type,
  Month startMonth = const Month(2026, 8),
  Month? endMonth,
  int? totalInstallments,
  int settledInstallments = 0,
}) {
  return Expense(
    id: 1,
    name: 'Despesa',
    type: type,
    amount: 100,
    dueDay: 10,
    startMonth: startMonth,
    endMonth: endMonth,
    totalInstallments: totalInstallments,
    settledInstallments: settledInstallments,
    createdAt: DateTime(2026, 8),
  );
}

void main() {
  group('despesa avulsa', () {
    final expense = buildExpense(type: ExpenseType.single);

    test('aparece somente no mês escolhido', () {
      expect(expense.occurrenceIn(const Month(2026, 8)), isNotNull);
      expect(expense.occurrenceIn(const Month(2026, 9)), isNull);
      expect(expense.occurrenceIn(const Month(2026, 7)), isNull);
    });
  });

  group('despesa recorrente', () {
    test('repete indefinidamente a partir do mês inicial', () {
      final expense = buildExpense(type: ExpenseType.recurring);

      expect(expense.occurrenceIn(const Month(2026, 7)), isNull);
      expect(expense.occurrenceIn(const Month(2026, 8)), isNotNull);
      expect(expense.occurrenceIn(const Month(2030, 1)), isNotNull);
    });

    test('para de aparecer depois do mês de encerramento', () {
      final expense = buildExpense(
        type: ExpenseType.recurring,
        endMonth: const Month(2026, 10),
      );

      expect(expense.occurrenceIn(const Month(2026, 10)), isNotNull);
      expect(expense.occurrenceIn(const Month(2026, 11)), isNull);
    });
  });

  group('despesa parcelada já em andamento', () {
    final expense = buildExpense(
      type: ExpenseType.installment,
      totalInstallments: 12,
      settledInstallments: 5,
    );

    test('retoma a contagem na parcela seguinte à última paga', () {
      expect(expense.occurrenceIn(const Month(2026, 8))!.installmentNumber, 6);
      expect(expense.occurrenceIn(const Month(2026, 9))!.installmentNumber, 7);
    });

    test('cobre exatamente as parcelas que faltam', () {
      expect(expense.remainingInstallments, 7);
      expect(expense.occurrenceIn(const Month(2027, 2))!.installmentNumber, 12);
      expect(expense.occurrenceIn(const Month(2027, 3)), isNull);
    });

    test('marca a última parcela e o mês final', () {
      expect(expense.lastMonth, const Month(2027, 2));
      expect(
        expense.occurrenceIn(const Month(2027, 2))!.isLastInstallment,
        isTrue,
      );
    });

    test('rotula a parcela para exibição', () {
      expect(
        expense.occurrenceIn(const Month(2026, 8))!.installmentLabel,
        '6 de 12',
      );
    });
  });
}
