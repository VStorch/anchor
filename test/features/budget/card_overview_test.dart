import 'package:anchor/core/utils/month.dart';
import 'package:anchor/features/budget/models/budget_snapshot.dart';
import 'package:anchor/features/budget/models/card_overview.dart';
import 'package:anchor/features/budget/models/month_summary.dart';
import 'package:anchor/features/cards/models/credit_card.dart';
import 'package:anchor/features/expenses/models/expense.dart';
import 'package:anchor/features/expenses/models/expense_payment.dart';
import 'package:anchor/features/expenses/models/expense_type.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  const august = Month(2026, 8);
  const september = Month(2026, 9);
  const october = Month(2026, 10);
  final today = DateTime(2026, 9, 15, 9);

  setUpAll(() => initializeDateFormatting('pt_BR'));

  final nubank = CreditCard(
    id: 1,
    name: 'Nubank',
    closingDay: 3,
    dueDay: 10,
    walletId: 1,
    createdAt: DateTime(2026),
  );

  Expense purchase({
    required int id,
    required DateTime purchasedAt,
    CreditCard? card,
    double amount = 100,
  }) {
    final on = card ?? nubank;
    return Expense(
      id: id,
      name: 'Compra $id',
      type: ExpenseType.single,
      amount: amount,
      dueDay: on.dueDay,
      startMonth: on.invoiceMonthFor(purchasedAt),
      walletId: 1,
      cardId: on.id,
      purchasedAt: purchasedAt,
      createdAt: DateTime(2026),
    );
  }

  CardOverview overviewOf(
    Month month, {
    List<Expense> expenses = const <Expense>[],
    List<ExpensePayment> payments = const <ExpensePayment>[],
    List<CreditCard> cards = const <CreditCard>[],
  }) {
    final withCards = cards.isEmpty ? [nubank] : cards;
    return BudgetSnapshot(
      summary: MonthSummary.build(
        month: month,
        expenses: expenses,
        payments: payments,
        receipts: const [],
        cards: withCards,
        today: today,
      ),
      walletSummaries: const [],
      expenses: expenses,
      wallets: const [],
      receipts: const [],
      payments: payments,
      cards: withCards,
    ).cardOverview.single;
  }

  test('o resumo dos cartões é montado uma vez por retrato', () {
    final snapshot = BudgetSnapshot(
      summary: MonthSummary.build(
        month: september,
        expenses: const [],
        payments: const [],
        receipts: const [],
        cards: [nubank],
        today: today,
      ),
      walletSummaries: const [],
      expenses: const [],
      wallets: const [],
      receipts: const [],
      payments: const [],
      cards: [nubank],
    );

    expect(identical(snapshot.cardOverview, snapshot.cardOverview), isTrue);
  });

  test('a fatura mostrada é a que recebe uma compra de hoje', () {
    final overview = overviewOf(
      september,
      expenses: [purchase(id: 1, purchasedAt: DateTime(2026, 9, 13))],
    );

    expect(overview.shown.month, october);
    expect(overview.isOpenInvoice, isTrue);
    expect(overview.shown.amount, 100);
    expect(overview.shown.statusLabel, 'Aberta · fecha 03/10');
  });

  test('vencimento antes do fechamento joga a fatura aberta dois meses à '
      'frente', () {
    final inter = CreditCard(
      id: 1,
      name: 'Inter',
      closingDay: 25,
      dueDay: 5,
      walletId: 1,
      createdAt: DateTime(2026),
    );

    final overview = overviewOf(
      september,
      cards: [inter],
      expenses: [
        purchase(id: 1, purchasedAt: DateTime(2026, 9, 13), card: inter),
      ],
    );

    expect(overview.shown.month, october);
    expect(inter.invoiceMonthFor(DateTime(2026, 9, 26)), const Month(2026, 11));
  });

  test('as faturas anteriores não pagas aparecem da mais antiga para a mais '
      'nova', () {
    final overview = overviewOf(
      september,
      expenses: [
        purchase(id: 1, purchasedAt: DateTime(2026, 7, 1)),
        purchase(id: 2, purchasedAt: DateTime(2026, 8, 1)),
      ],
    );

    expect(overview.pending.map((invoice) => invoice.month), [
      const Month(2026, 7),
      august,
    ]);
    expect(overview.pending.first.isOverdue, isTrue);
  });

  test('a fatura paga fica fora das pendentes', () {
    final paid = purchase(id: 1, purchasedAt: DateTime(2026, 8, 1));

    final overview = overviewOf(
      september,
      expenses: [paid],
      payments: [
        ExpensePayment(
          expenseId: 1,
          walletId: 1,
          month: august,
          amount: 100,
          paidAt: DateTime(2026, 8, 10),
        ),
      ],
    );

    expect(overview.pending, isEmpty);
    expect(overview.shown.month, october);
  });

  test('uma fatura sem compras não tem pendência nem valor', () {
    final overview = overviewOf(september);

    expect(overview.pending, isEmpty);
    expect(overview.shown.items, isEmpty);
    expect(overview.shown.statusLabel, 'Sem compras · fecha 03/10');
  });

  test('num mês que não é o corrente só aparece a fatura daquele mês', () {
    final overview = overviewOf(
      august,
      expenses: [
        purchase(id: 1, purchasedAt: DateTime(2026, 7, 1)),
        purchase(id: 2, purchasedAt: DateTime(2026, 9, 13)),
      ],
    );

    expect(overview.shown.month, august);
    expect(overview.isOpenInvoice, isFalse);
    expect(overview.pending, isEmpty);
  });
}
