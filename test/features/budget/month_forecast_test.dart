import 'package:anchor/core/utils/month.dart';
import 'package:anchor/features/budget/models/everyday_spending.dart';
import 'package:anchor/features/budget/models/month_forecast.dart';
import 'package:anchor/features/budget/models/month_summary.dart';
import 'package:anchor/features/budget/models/wallet_summary.dart';
import 'package:anchor/features/cards/models/credit_card.dart';
import 'package:anchor/features/expenses/models/expense.dart';
import 'package:anchor/features/expenses/models/expense_type.dart';
import 'package:anchor/features/wallets/models/balance_check.dart';
import 'package:anchor/features/wallets/models/outflow.dart';
import 'package:anchor/features/wallets/models/payout.dart';
import 'package:anchor/features/wallets/models/payout_schedule.dart';
import 'package:anchor/features/wallets/models/receipt.dart';
import 'package:anchor/features/wallets/models/receipt_status.dart';
import 'package:anchor/features/wallets/models/wallet.dart';
import 'package:anchor/features/wallets/models/wallet_kind.dart';
import 'package:flutter_test/flutter_test.dart';

const Month september = Month(2026, 9);
const Month october = Month(2026, 10);

final DateTime today = DateTime(2026, 9, 13, 10);

final Wallet salary = Wallet(
  id: 1,
  name: 'Salário',
  kind: WalletKind.salary,
  colorIndex: 0,
  createdAt: DateTime(2026, 9),
  payouts: [
    Payout(
      id: 1,
      walletId: 1,
      label: 'Mensal',
      amount: 3200,
      day: 5,
      schedule: PayoutSchedule.businessDay,
      createdAt: DateTime(2026, 9),
    ),
  ],
);

final Wallet voucher = Wallet(
  id: 2,
  name: 'Vale refeição',
  kind: WalletKind.benefit,
  colorIndex: 1,
  createdAt: DateTime(2026, 9),
  payouts: [
    Payout(
      id: 2,
      walletId: 2,
      label: 'Mensal',
      amount: 600,
      day: 1,
      createdAt: DateTime(2026, 9),
    ),
  ],
);

Receipt receiptOf(
  Wallet wallet,
  Month month, {
  ReceiptStatus status = ReceiptStatus.confirmed,
}) {
  final payout = wallet.payouts.single;
  return Receipt(
    walletId: wallet.id!,
    payoutId: payout.id,
    month: month,
    amount: payout.amount,
    receivedAt: payout.dateIn(month),
    status: status,
  );
}

Expense bill({
  required int id,
  required double amount,
  int? walletId,
  int? cardId,
  ExpenseType type = ExpenseType.recurring,
  Month startMonth = september,
}) => Expense(
  id: id,
  name: 'Conta $id',
  type: type,
  amount: amount,
  dueDay: 20,
  startMonth: startMonth,
  walletId: walletId,
  cardId: cardId,
  createdAt: DateTime(2026, 9),
);

MonthForecast? forecastOf(
  Month month, {
  DateTime? now,
  List<Wallet>? wallets,
  List<Receipt> receipts = const <Receipt>[],
  List<Expense> expenses = const <Expense>[],
  List<BalanceCheck> checks = const <BalanceCheck>[],
  List<CreditCard> cards = const <CreditCard>[],
  List<Outflow> outflows = const <Outflow>[],
}) {
  final clock = now ?? today;
  MonthSummary summaryOf(Month month) => MonthSummary.build(
    month: month,
    expenses: expenses,
    payments: const [],
    receipts: receipts,
    cards: cards,
    today: clock,
  );

  final summary = summaryOf(month);
  return MonthForecast.build(
    month: month,
    today: clock,
    walletSummaries: WalletSummary.buildAll(
      month: month,
      wallets: wallets ?? [salary],
      receipts: receipts,
      payments: const [],
      occurrences: summary.occurrences,
      checks: checks,
      outflows: outflows,
    ),
    receipts: receipts,
    spending: EverydaySpending.collect(
      outflows: outflows,
      expenses: expenses,
      cards: cards,
    ),
    monthsAhead: [
      for (var ahead = Month.fromDate(clock); ahead < month; ahead = ahead.next)
        summaryOf(ahead),
      summary,
    ],
  );
}

void main() {
  group('MonthForecast', () {
    test('no mês corrente conta o salário que ainda vai cair', () {
      final forecast = forecastOf(
        september,
        now: DateTime(2026, 9, 3),
        expenses: [bill(id: 1, amount: 1200, walletId: 1)],
      )!;

      expect(forecast.freeMoney.toReceive, 3200);
      expect(forecast.freeMoney.toPay, 1200);
      expect(forecast.freeMoney.endBalance, 2000);
    });

    test(
      'a entrada prevista vencida e não confirmada conta como a receber',
      () {
        final forecast = forecastOf(
          september,
          receipts: [
            receiptOf(salary, september, status: ReceiptStatus.predicted),
          ],
        )!;

        expect(forecast.freeMoney.toReceive, 3200);
        expect(forecast.wallets.single.startBalance, 0);
      },
    );

    test('a entrada confirmada ou dispensada não se repete na previsão', () {
      final confirmed = forecastOf(
        september,
        receipts: [receiptOf(salary, september)],
      )!;
      final skipped = forecastOf(
        september,
        receipts: [receiptOf(salary, september, status: ReceiptStatus.skipped)],
      )!;

      expect(confirmed.freeMoney.toReceive, 0);
      expect(confirmed.freeMoney.endBalance, 3200);
      expect(skipped.freeMoney.toReceive, 0);
      expect(skipped.freeMoney.endBalance, 0);
    });

    test('um mês futuro soma o que falta deste mês e do seguinte', () {
      final forecast = forecastOf(
        october,
        receipts: [receiptOf(salary, september)],
        expenses: [
          bill(id: 1, amount: 1000, walletId: 1),
          bill(
            id: 2,
            amount: 150,
            walletId: 1,
            type: ExpenseType.single,
            startMonth: october,
          ),
        ],
      )!;

      expect(forecast.month, october);
      expect(forecast.freeMoney.toReceive, 3200);
      expect(forecast.freeMoney.toPay, 2150);
      expect(forecast.freeMoney.endBalance, 4250);
    });

    test('um mês passado não tem previsão', () {
      expect(forecastOf(const Month(2026, 8)), isNull);
    });

    test('a conta sem carteira definida fica à parte', () {
      final forecast = forecastOf(
        september,
        receipts: [receiptOf(salary, september)],
        expenses: [
          bill(id: 1, amount: 400, walletId: 1),
          bill(id: 2, amount: 90.5),
          bill(id: 3, amount: 10, walletId: 99),
        ],
      )!;

      expect(forecast.wallets.single.toPay, 400);
      expect(forecast.unassignedToPay, 100.5);
      expect(forecast.freeMoney.toPay, 400);
      expect(forecast.freeMoney.endBalance, 2699.5);
    });

    test('a fatura do cartão conta pela carteira que paga o cartão', () {
      final card = CreditCard(
        id: 7,
        name: 'Nubank',
        closingDay: 3,
        dueDay: 10,
        walletId: 2,
        createdAt: DateTime(2026, 9),
      );
      final forecast = forecastOf(
        october,
        wallets: [salary, voucher],
        receipts: [receiptOf(salary, september), receiptOf(voucher, september)],
        cards: [card],
        expenses: [
          bill(
            id: 1,
            amount: 250,
            walletId: 2,
            cardId: 7,
            type: ExpenseType.single,
            startMonth: october,
          ),
        ],
      )!;

      expect(forecast.wallets.last.toPay, 250);
      expect(forecast.wallets.first.toPay, 0);
      expect(forecast.unassignedToPay, 0);
    });

    test(
      'sem salário, a conta sem carteira deixa o dinheiro livre negativo',
      () {
        final forecast = forecastOf(
          september,
          wallets: [voucher],
          receipts: [receiptOf(voucher, september)],
          expenses: [bill(id: 1, amount: 300)],
        )!;

        expect(forecast.freeMoney.wallets, isEmpty);
        expect(forecast.freeMoney.isEmpty, isFalse);
        expect(forecast.freeMoney.endBalance, -300);
        expect(forecast.benefits.endBalance, 600);
      },
    );

    test('o benefício com mais contas do que saldo vai faltar', () {
      final forecast = forecastOf(
        september,
        wallets: [salary, voucher],
        receipts: [receiptOf(salary, september), receiptOf(voucher, september)],
        expenses: [bill(id: 1, amount: 650, walletId: 2)],
      )!;

      expect(forecast.shortBenefits.single.wallet.name, 'Vale refeição');
      expect(forecast.benefits.endBalance, -50);
      expect(forecast.freeMoney.endBalance, 3200);
    });

    group('reserva do dia a dia', () {
      final reserved = salary.copyWith(monthlyReserve: 500);

      test('setembro desconta a reserva do dinheiro livre', () {
        final forecast = forecastOf(
          september,
          wallets: [reserved, voucher],
          receipts: [
            receiptOf(reserved, september),
            receiptOf(voucher, september),
          ],
          expenses: [bill(id: 1, amount: 1200, walletId: 1)],
        )!;

        expect(forecast.freeMoney.reserve, 500);
        expect(forecast.freeMoney.endBalance, 1500);
        expect(forecast.freeMoney.lacksReserve, isFalse);
        expect(forecast.benefits.reserve, 0);
        expect(forecast.benefits.endBalance, 600);
      });

      test('outubro soma a reserva de cada mês até a tela', () {
        final forecast = forecastOf(
          october,
          wallets: [reserved],
          receipts: [receiptOf(reserved, september)],
          expenses: [bill(id: 1, amount: 1200, walletId: 1)],
        )!;

        expect(forecast.freeMoney.reserve, 1000);
        expect(forecast.freeMoney.endBalance, 3200 + 3200 - 2400 - 1000);
      });

      test('os gastos do mês consomem a reserva até zerar', () {
        Outflow spent(double amount) => Outflow(
          walletId: 1,
          description: 'Mercado',
          amount: amount,
          spentAt: DateTime(2026, 9, 10),
        );

        final partly = forecastOf(
          september,
          wallets: [reserved],
          outflows: [spent(180)],
        )!;
        final beyond = forecastOf(
          september,
          wallets: [reserved],
          outflows: [spent(420), spent(200)],
        )!;

        expect(partly.freeMoney.reserve, 320);
        expect(beyond.freeMoney.reserve, 0);
      });

      group('compra no cartão pago pelo salário', () {
        final card = CreditCard(
          id: 7,
          name: 'Nubank',
          closingDay: 3,
          dueDay: 10,
          walletId: 1,
          createdAt: DateTime(2026, 9),
        );

        Expense purchase({
          required int id,
          ExpenseType type = ExpenseType.single,
          DateTime? purchasedAt,
        }) => Expense(
          id: id,
          name: 'Compra $id',
          type: type,
          amount: 120,
          dueDay: 10,
          startMonth: october,
          totalInstallments: type == ExpenseType.installment ? 3 : null,
          walletId: 1,
          cardId: 7,
          purchasedAt: purchasedAt ?? DateTime(2026, 9, 12),
          createdAt: DateTime(2026, 9),
        );

        test('a compra à vista deste mês consome a reserva', () {
          final forecast = forecastOf(
            september,
            wallets: [reserved],
            cards: [card],
            expenses: [purchase(id: 1)],
          )!;

          expect(forecast.freeMoney.reserve, 380);
        });

        test('a parcelada e a de outro mês não consomem', () {
          final forecast = forecastOf(
            september,
            wallets: [reserved],
            cards: [card],
            expenses: [
              purchase(id: 1, type: ExpenseType.installment),
              purchase(id: 2, purchasedAt: DateTime(2026, 8, 30)),
            ],
          )!;

          expect(forecast.freeMoney.reserve, 500);
        });
      });

      test('sem reserva em nenhum salário, a previsão avisa que falta', () {
        final forecast = forecastOf(september)!;

        expect(forecast.freeMoney.lacksReserve, isTrue);
        expect(forecast.freeMoney.reserve, 0);
      });

      test('o benefício nunca reserva, mesmo com o valor gravado', () {
        final forecast = forecastOf(
          september,
          wallets: [voucher.copyWith(monthlyReserve: 300)],
          receipts: [receiptOf(voucher, september)],
        )!;

        expect(forecast.benefits.reserve, 0);
        expect(forecast.benefits.endBalance, 600);
      });
    });

    test('o salário e o vale de setembro fecham a conta de hoje', () {
      final forecast = forecastOf(
        september,
        wallets: [salary, voucher],
        receipts: [receiptOf(salary, september), receiptOf(voucher, september)],
        checks: [
          BalanceCheck(walletId: 1, amount: 850, checkedAt: today),
          BalanceCheck(walletId: 2, amount: 162.70, checkedAt: today),
        ],
        expenses: [bill(id: 1, amount: 464.90, walletId: 1)],
      )!;

      expect(forecast.freeMoney.toReceive, 0);
      expect(forecast.freeMoney.endBalance, 385.10);
      expect(forecast.benefits.endBalance, 162.70);
    });
  });
}
