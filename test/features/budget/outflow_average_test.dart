import 'package:anchor/core/utils/month.dart';
import 'package:anchor/features/budget/models/everyday_spending.dart';
import 'package:anchor/features/budget/models/outflow_average.dart';
import 'package:anchor/features/cards/models/credit_card.dart';
import 'package:anchor/features/expenses/models/expense.dart';
import 'package:anchor/features/expenses/models/expense_type.dart';
import 'package:anchor/features/wallets/models/outflow.dart';
import 'package:anchor/features/wallets/models/wallet.dart';
import 'package:anchor/features/wallets/models/wallet_kind.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final today = DateTime(2026, 9, 15);
  final salary = Wallet(
    id: 1,
    name: 'Salário',
    kind: WalletKind.salary,
    colorIndex: 0,
    createdAt: DateTime(2026, 5, 20),
  );

  Outflow spent(int month, double amount, {int walletId = 1}) => Outflow(
    walletId: walletId,
    description: 'Mercado',
    amount: amount,
    spentAt: DateTime(2026, month, 10),
  );

  List<EverydaySpending> spendingOf(
    List<Outflow> outflows, {
    List<Expense> expenses = const <Expense>[],
    List<CreditCard> cards = const <CreditCard>[],
  }) => EverydaySpending.collect(
    outflows: outflows,
    expenses: expenses,
    cards: cards,
  );

  OutflowAverage? averageOf(List<Outflow> outflows) => OutflowAverage.of(
    wallet: salary,
    spending: spendingOf(outflows),
    today: today,
  );

  test('sem gastos lançados não há média para sugerir', () {
    expect(averageOf(const []), isNull);
    expect(averageOf([spent(9, 80)]), isNull);
  });

  test('os meses antes do cadastro da carteira também contam', () {
    final average = averageOf([spent(3, 400), spent(5, 440)])!;

    expect(average.amount, 420);
    expect(average.from, const Month(2026, 3));
  });

  test('a compra à vista no cartão pago pelo salário entra na média', () {
    final card = CreditCard(
      id: 7,
      name: 'Nubank',
      closingDay: 3,
      dueDay: 10,
      walletId: 1,
      createdAt: DateTime(2026),
    );
    Expense purchase(ExpenseType type) => Expense(
      name: 'Compra',
      type: type,
      amount: 200,
      dueDay: 10,
      startMonth: const Month(2026, 9),
      totalInstallments: type == ExpenseType.installment ? 5 : null,
      cardId: 7,
      walletId: 1,
      purchasedAt: DateTime(2026, 8, 2),
      createdAt: DateTime(2026),
    );

    final average = OutflowAverage.of(
      wallet: salary,
      spending: spendingOf(
        [spent(8, 300)],
        expenses: [
          purchase(ExpenseType.single),
          purchase(ExpenseType.installment),
        ],
        cards: [card],
      ),
      today: today,
    )!;

    expect(average.amount, 500);
  });

  test('a média de dois meses completos', () {
    final average = averageOf([
      spent(7, 400),
      spent(7, 50),
      spent(8, 390),
      spent(8, 100, walletId: 2),
    ])!;

    expect(average.amount, 420);
    expect(
      (average.from, average.to),
      (const Month(2026, 7), const Month(2026, 8)),
    );
  });

  test('um mês sem gasto lançado não puxa a média para baixo', () {
    final average = averageOf([spent(6, 300), spent(8, 500)])!;

    expect(average.amount, 400);
    expect(average.from, const Month(2026, 6));
  });

  test('conta só os três últimos meses com gasto', () {
    final older = Wallet(
      id: 1,
      name: 'Salário',
      kind: WalletKind.salary,
      colorIndex: 0,
      createdAt: DateTime(2026),
    );

    final average = OutflowAverage.of(
      wallet: older,
      spending: spendingOf([
        spent(3, 1000),
        spent(6, 300),
        spent(7, 300),
        spent(8, 600),
      ]),
      today: today,
    )!;

    expect(average.amount, 400);
    expect(average.from, const Month(2026, 6));
  });
}
