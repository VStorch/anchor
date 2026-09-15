import 'package:anchor/core/utils/month.dart';
import 'package:anchor/features/budget/models/budget_snapshot.dart';
import 'package:anchor/features/budget/models/month_summary.dart';
import 'package:anchor/features/cards/models/credit_card.dart';
import 'package:anchor/features/expenses/models/expense.dart';
import 'package:anchor/features/expenses/models/expense_payment.dart';
import 'package:anchor/features/expenses/models/expense_type.dart';
import 'package:anchor/features/wallets/models/balance_check.dart';
import 'package:anchor/features/wallets/models/outflow.dart';
import 'package:anchor/features/wallets/models/receipt.dart';
import 'package:anchor/features/wallets/models/receipt_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const september = Month(2026, 9);
  const salaryId = 1;
  const voucherId = 2;

  Expense bill(int id, {int? walletId, int? cardId}) => Expense(
    id: id,
    name: 'Conta $id',
    type: ExpenseType.recurring,
    amount: 100,
    dueDay: 10,
    startMonth: september,
    walletId: walletId,
    cardId: cardId,
    createdAt: DateTime(2026, 9),
  );

  Receipt receipt(int walletId, {ReceiptStatus? status}) => Receipt(
    walletId: walletId,
    month: september,
    amount: 3000,
    receivedAt: DateTime(2026, 9, 5),
    status: status ?? ReceiptStatus.confirmed,
  );

  ExpensePayment payment(int expenseId, Month month) => ExpensePayment(
    expenseId: expenseId,
    walletId: salaryId,
    month: month,
    amount: 50,
    paidAt: month.dayOf(10),
  );

  test('conta o que excluir a carteira apaga e o que fica sem ela', () {
    final snapshot = BudgetSnapshot(
      summary: MonthSummary.empty(september),
      walletSummaries: const [],
      wallets: const [],
      expenses: [
        bill(1, walletId: salaryId),
        bill(2, walletId: salaryId),
        bill(3, walletId: salaryId, cardId: 1),
        bill(4, walletId: voucherId),
      ],
      receipts: [
        receipt(salaryId),
        receipt(salaryId),
        receipt(salaryId, status: ReceiptStatus.predicted),
        receipt(voucherId),
      ],
      payments: [
        payment(1, september),
        payment(1, september),
        payment(1, const Month(2026, 8)),
        payment(2, september),
      ],
      outflows: [
        Outflow(
          walletId: salaryId,
          description: 'Mercado',
          amount: 47.9,
          spentAt: DateTime(2026, 9, 12),
        ),
        Outflow(
          walletId: voucherId,
          description: 'Almoço',
          amount: 30,
          spentAt: DateTime(2026, 9, 12),
        ),
      ],
      checks: [
        BalanceCheck(
          walletId: salaryId,
          amount: 850,
          checkedAt: DateTime(2026, 9, 13),
        ),
      ],
      cards: [
        CreditCard(
          id: 1,
          name: 'Nubank',
          closingDay: 3,
          dueDay: 10,
          walletId: salaryId,
          createdAt: DateTime(2026, 9),
        ),
      ],
    );

    final impact = snapshot.deletionImpactOf(salaryId);

    expect(impact.receipts, 2);
    expect(impact.outflows, 1);
    expect(impact.checks, 1);
    expect(impact.paidBills, 3);
    expect(impact.plannedBills, 2);
    expect(impact.cards, 1);
    expect(impact.isEmpty, isFalse);
    expect(snapshot.deletionImpactOf(3).isEmpty, isTrue);
  });
}
