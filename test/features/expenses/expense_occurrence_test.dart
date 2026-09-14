import 'package:anchor/core/utils/month.dart';
import 'package:anchor/features/expenses/models/expense.dart';
import 'package:anchor/features/expenses/models/expense_payment.dart';
import 'package:anchor/features/expenses/models/expense_type.dart';
import 'package:flutter_test/flutter_test.dart';

const Month september = Month(2026, 9);

final Expense market = Expense(
  id: 1,
  name: 'Mercado',
  type: ExpenseType.recurring,
  amount: 600,
  dueDay: 10,
  startMonth: september,
  walletId: 2,
  createdAt: DateTime(2026, 9),
);

ExpensePayment payment({required double amount, int? walletId}) =>
    ExpensePayment(
      expenseId: 1,
      walletId: walletId,
      month: september,
      amount: amount,
      paidAt: DateTime(2026, 9, 10),
      settledOutside: walletId == null,
    );

void main() {
  group('ExpenseOccurrence', () {
    test('sem pagamento nenhum, deve o valor inteiro', () {
      final occurrence = market.occurrenceIn(september)!;

      expect(occurrence.amount, 600);
      expect(occurrence.paidAmount, 0);
      expect(occurrence.remaining, 600);
      expect(occurrence.isPaid, isFalse);
      expect(occurrence.isPartlyPaid, isFalse);
    });

    test('soma pagamentos de carteiras diferentes', () {
      final occurrence = market
          .occurrenceIn(september)!
          .withLedger(
            payments: [
              payment(amount: 400, walletId: 2),
              payment(amount: 200, walletId: 1),
            ],
          );

      expect(occurrence.paidAmount, 600);
      expect(occurrence.remaining, 0);
      expect(occurrence.isPaid, isTrue);
      expect(occurrence.paidWalletIds, [2, 1]);
    });

    test('fica parcial enquanto falta dinheiro', () {
      final occurrence = market
          .occurrenceIn(september)!
          .withLedger(payments: [payment(amount: 400, walletId: 2)]);

      expect(occurrence.isPartlyPaid, isTrue);
      expect(occurrence.isPaid, isFalse);
      expect(occurrence.remaining, 200);
      expect(occurrence.paidRatio, closeTo(0.666, 0.001));
    });

    test('o valor do mês substitui o da regra e fecha a conta', () {
      final occurrence = market
          .occurrenceIn(september)!
          .withLedger(
            monthAmount: 550,
            payments: [
              payment(amount: 400, walletId: 2),
              payment(amount: 150, walletId: 1),
            ],
          );

      expect(occurrence.hasCustomAmount, isTrue);
      expect(occurrence.amount, 550);
      expect(occurrence.expense.amount, 600);
      expect(occurrence.isPaid, isTrue);
      expect(occurrence.remaining, 0);
    });

    test('tolera a diferença de centavo da soma', () {
      final occurrence = market
          .occurrenceIn(september)!
          .withLedger(
            monthAmount: 0.3,
            payments: [payment(amount: 0.1), payment(amount: 0.2)],
          );

      expect(occurrence.isPaid, isTrue);
    });

    test('pagar acima do valor não deixa saldo negativo', () {
      final occurrence = market
          .occurrenceIn(september)!
          .withLedger(payments: [payment(amount: 700, walletId: 1)]);

      expect(occurrence.remaining, 0);
      expect(occurrence.isPaid, isTrue);
    });
  });
}
