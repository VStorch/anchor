import 'package:anchor/core/utils/month.dart';
import 'package:anchor/features/budget/models/month_summary.dart';
import 'package:anchor/features/budget/models/wallet_summary.dart';
import 'package:anchor/features/expenses/models/expense.dart';
import 'package:anchor/features/expenses/models/expense_month.dart';
import 'package:anchor/features/expenses/models/expense_payment.dart';
import 'package:anchor/features/expenses/models/expense_type.dart';
import 'package:anchor/features/wallets/models/outflow.dart';
import 'package:anchor/features/wallets/models/payout.dart';
import 'package:anchor/features/wallets/models/receipt.dart';
import 'package:anchor/features/wallets/models/receipt_kind.dart';
import 'package:anchor/features/wallets/models/wallet.dart';
import 'package:anchor/features/wallets/models/wallet_kind.dart';
import 'package:flutter_test/flutter_test.dart';

const Month august = Month(2026, 8);

Wallet buildWallet({
  required int id,
  required WalletKind kind,
  required double monthly,
}) {
  return Wallet(
    id: id,
    name: kind == WalletKind.salary ? 'Salário' : 'Vale refeição',
    kind: kind,
    colorIndex: 0,
    createdAt: DateTime(2026),
    payouts: [Payout(walletId: id, label: 'Entrada', amount: monthly, day: 5)],
  );
}

Expense buildExpense({
  required int id,
  required ExpenseType type,
  required double amount,
  int? walletId,
  int? totalInstallments,
  int settledInstallments = 0,
}) {
  return Expense(
    id: id,
    name: 'Despesa $id',
    type: type,
    amount: amount,
    dueDay: 10,
    startMonth: august,
    totalInstallments: totalInstallments,
    settledInstallments: settledInstallments,
    walletId: walletId,
    createdAt: DateTime(2026, 8),
  );
}

void main() {
  final salary = buildWallet(id: 1, kind: WalletKind.salary, monthly: 3000);
  final voucher = buildWallet(id: 2, kind: WalletKind.benefit, monthly: 600);

  final expenses = [
    buildExpense(id: 1, type: ExpenseType.recurring, amount: 500, walletId: 1),
    buildExpense(
      id: 2,
      type: ExpenseType.installment,
      amount: 200,
      walletId: 1,
      totalInstallments: 10,
      settledInstallments: 4,
    ),
    buildExpense(id: 3, type: ExpenseType.single, amount: 300, walletId: 2),
  ];

  final receipts = [
    Receipt(
      walletId: 1,
      payoutId: 1,
      month: august,
      amount: 3000,
      receivedAt: DateTime(2026, 8, 5),
    ),
    Receipt(
      walletId: 2,
      payoutId: 2,
      month: august,
      amount: 600,
      receivedAt: DateTime(2026, 8, 5),
    ),
    Receipt(
      walletId: 1,
      payoutId: 1,
      month: const Month(2026, 7),
      amount: 3000,
      receivedAt: DateTime(2026, 7, 5),
    ),
  ];

  final payments = [
    ExpensePayment(
      expenseId: 1,
      walletId: 1,
      month: august,
      amount: 500,
      paidAt: DateTime(2026, 8, 10),
    ),
  ];

  MonthSummary buildSummary() => MonthSummary.build(
    month: august,
    expenses: expenses,
    payments: payments,
    receipts: receipts,
    wallets: [salary, voucher],
  );

  group('MonthSummary', () {
    test('soma apenas as despesas que caem no mês', () {
      expect(buildSummary().totalExpenses, 1000);
    });

    test('separa o que já foi pago do que falta', () {
      final summary = buildSummary();

      expect(summary.totalPaid, 500);
      expect(summary.totalPending, 500);
      expect(summary.paidRatio, 0.5);
    });

    test('considera somente os recebimentos do mês', () {
      expect(buildSummary().totalReceived, 3600);
    });

    test('calcula o saldo como recebido menos pago', () {
      expect(buildSummary().balance, 3100);
    });

    test('projeta o mês a partir da renda esperada', () {
      final summary = buildSummary();

      expect(summary.expectedIncome, 3600);
      expect(summary.projectedBalance, 2600);
    });

    test('ordena as ocorrências por vencimento', () {
      final summary = buildSummary();

      expect(summary.occurrences.length, 3);
      expect(
        summary.occurrences.map((occurrence) => occurrence.dueDate),
        isA<Iterable<DateTime>>(),
      );
    });
  });

  group('MonthSummary com pagamento dividido', () {
    final split = [
      ExpensePayment(
        expenseId: 3,
        walletId: 2,
        month: august,
        amount: 200,
        paidAt: DateTime(2026, 8, 10),
      ),
      ExpensePayment(
        expenseId: 3,
        walletId: 1,
        month: august,
        amount: 100,
        paidAt: DateTime(2026, 8, 11),
      ),
    ];

    MonthSummary buildSplit({List<ExpenseMonth> monthAmounts = const []}) =>
        MonthSummary.build(
          month: august,
          expenses: expenses,
          payments: [...payments, ...split],
          receipts: receipts,
          wallets: [salary, voucher],
          monthAmounts: monthAmounts,
        );

    test('soma as duas carteiras na mesma despesa', () {
      final occurrence = buildSplit().occurrenceOf(3)!;

      expect(occurrence.paidAmount, 300);
      expect(occurrence.isPaid, isTrue);
      expect(occurrence.paidWalletIds, [2, 1]);
    });

    test('conta o valor dividido no total pago do mês', () {
      expect(buildSplit().totalPaid, 800);
      expect(buildSplit().totalPending, 200);
    });

    test('o valor do mês entra no total no lugar do valor da regra', () {
      final summary = buildSplit(
        monthAmounts: [ExpenseMonth(expenseId: 3, month: august, amount: 250)],
      );

      expect(summary.totalExpenses, 950);
      expect(summary.occurrenceOf(3)!.amount, 250);
      expect(summary.occurrenceOf(3)!.isPaid, isTrue);
    });
  });

  group('ajuste de saldo', () {
    final withAdjustment = [
      ...receipts,
      Receipt(
        walletId: 1,
        month: august,
        amount: 2000,
        receivedAt: DateTime(2026, 8, 2),
        kind: ReceiptKind.adjustment,
      ),
    ];

    MonthSummary buildAdjusted() => MonthSummary.build(
      month: august,
      expenses: expenses,
      payments: payments,
      receipts: withAdjustment,
      wallets: [salary, voucher],
    );

    test('não conta como entrada do mês', () {
      expect(buildAdjusted().totalReceived, 3600);
    });

    test('entra no saldo da carteira', () {
      final summaries = WalletSummary.buildAll(
        month: august,
        wallets: [salary, voucher],
        receipts: withAdjustment,
        payments: payments,
        occurrences: buildAdjusted().occurrences,
      );

      expect(summaries.first.balance, 7500);
      expect(summaries.first.receivedInMonth, 3000);
    });
  });

  group('gasto avulso', () {
    final outflows = [
      Outflow(
        walletId: 2,
        description: 'Mercado',
        amount: 120,
        spentAt: DateTime(2026, 8, 12),
      ),
      Outflow(
        walletId: 2,
        description: 'Padaria',
        amount: 30,
        spentAt: DateTime(2026, 7, 12),
      ),
    ];

    MonthSummary buildWithOutflows() => MonthSummary.build(
      month: august,
      expenses: expenses,
      payments: payments,
      receipts: receipts,
      wallets: [salary, voucher],
      outflows: outflows,
    );

    test('conta só os gastos do mês', () {
      expect(buildWithOutflows().totalOutflows, 120);
    });

    test('soma ao que foi pago das contas', () {
      final summary = buildWithOutflows();

      expect(summary.totalSpent, 620);
      expect(summary.balance, 2980);
    });

    test('não entra no total das contas do mês', () {
      final summary = buildWithOutflows();

      expect(summary.totalExpenses, 1000);
      expect(summary.totalPending, 500);
    });

    test('desconta do saldo e do gasto da carteira', () {
      final benefit = WalletSummary.buildAll(
        month: august,
        wallets: [salary, voucher],
        receipts: receipts,
        payments: payments,
        occurrences: buildWithOutflows().occurrences,
        outflows: outflows,
      ).last;

      expect(benefit.spentInMonth, 120);
      expect(benefit.balance, 450);
      expect(benefit.committedInMonth, 420);
    });
  });

  group('WalletSummary', () {
    late List<WalletSummary> summaries;

    setUp(() {
      summaries = WalletSummary.buildAll(
        month: august,
        wallets: [salary, voucher],
        receipts: receipts,
        payments: payments,
        occurrences: buildSummary().occurrences,
      );
    });

    test('acumula o saldo de todos os meses', () {
      expect(summaries.first.balance, 5500);
    });

    test('mostra o que ainda está comprometido no mês', () {
      expect(summaries.first.committedInMonth, 700);
      expect(summaries.first.pendingInMonth, 200);
    });

    test('isola cada carteira', () {
      final benefit = summaries.last;

      expect(benefit.receivedInMonth, 600);
      expect(benefit.spentInMonth, 0);
      expect(benefit.committedInMonth, 300);
    });
  });
}
