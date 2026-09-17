import 'package:anchor/core/utils/month.dart';
import 'package:anchor/features/budget/models/month_forecast.dart';
import 'package:anchor/features/budget/models/month_summary.dart';
import 'package:anchor/features/budget/models/wallet_summary.dart';
import 'package:anchor/features/cards/models/credit_card.dart';
import 'package:anchor/features/expenses/models/expense.dart';
import 'package:anchor/features/expenses/models/expense_type.dart';
import 'package:anchor/features/wallets/models/balance_check.dart';
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
    ),
    receipts: receipts,
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
