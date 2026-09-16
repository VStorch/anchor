import 'package:anchor/core/utils/month.dart';
import 'package:anchor/features/budget/models/month_reconciliation.dart';
import 'package:anchor/features/budget/models/month_summary.dart';
import 'package:anchor/features/budget/models/wallet_summary.dart';
import 'package:anchor/features/expenses/models/expense.dart';
import 'package:anchor/features/expenses/models/expense_payment.dart';
import 'package:anchor/features/expenses/models/expense_type.dart';
import 'package:anchor/features/wallets/models/balance_check.dart';
import 'package:anchor/features/wallets/models/outflow.dart';
import 'package:anchor/features/wallets/models/payout.dart';
import 'package:anchor/features/wallets/models/payout_schedule.dart';
import 'package:anchor/features/wallets/models/receipt.dart';
import 'package:anchor/features/wallets/models/wallet.dart';
import 'package:anchor/features/wallets/models/wallet_kind.dart';
import 'package:flutter_test/flutter_test.dart';

/// Mariana in 15/09/2026: salary and voucher already received, four bills
/// paid before she informed the balance at 9h04, one bill and one outflow
/// after it.
void main() {
  const september = Month(2026, 9);
  const october = Month(2026, 10);
  final today = DateTime(2026, 9, 15, 14);
  final checkedAt = DateTime(2026, 9, 15, 9, 4);

  final salary = Wallet(
    id: 1,
    name: 'Salário',
    kind: WalletKind.salary,
    colorIndex: 0,
    createdAt: DateTime(2026, 9),
    payouts: [
      Payout(
        id: 1,
        walletId: 1,
        label: '',
        amount: 3200,
        day: 5,
        schedule: PayoutSchedule.businessDay,
        createdAt: DateTime(2026, 9),
      ),
    ],
  );
  final voucher = Wallet(
    id: 2,
    name: 'VR',
    kind: WalletKind.benefit,
    colorIndex: 1,
    createdAt: DateTime(2026, 9),
    payouts: [
      Payout(
        id: 2,
        walletId: 2,
        label: '',
        amount: 600,
        day: 1,
        createdAt: DateTime(2026, 9),
      ),
    ],
  );

  final receipts = [
    Receipt(
      id: 1,
      walletId: 1,
      payoutId: 1,
      month: september,
      amount: 3200,
      receivedAt: DateTime(2026, 9, 8),
    ),
    Receipt(
      id: 2,
      walletId: 2,
      payoutId: 2,
      month: september,
      amount: 600,
      receivedAt: DateTime(2026, 9),
    ),
  ];

  final bills = <int, double>{1: 1100, 2: 89, 3: 110, 4: 115, 5: 99.90};
  final expenses = [
    for (final entry in bills.entries)
      Expense(
        id: entry.key,
        name: 'Conta ${entry.key}',
        type: ExpenseType.recurring,
        amount: entry.value,
        dueDay: 10,
        startMonth: september,
        walletId: 1,
        createdAt: DateTime(2026, 9),
      ),
  ];

  ExpensePayment payment(int expenseId, double amount, DateTime paidAt) =>
      ExpensePayment(
        expenseId: expenseId,
        walletId: 1,
        month: september,
        amount: amount,
        paidAt: paidAt,
      );

  final payments = [
    payment(1, 1100, DateTime(2026, 9, 10, 12)),
    payment(2, 89, DateTime(2026, 9, 12, 12)),
    payment(3, 110, DateTime(2026, 9, 5, 12)),
    payment(4, 115, DateTime(2026, 9, 14, 12)),
    payment(5, 99.90, DateTime(2026, 9, 15, 10)),
  ];

  final outflows = [
    Outflow(
      id: 1,
      walletId: 2,
      description: 'Mercado',
      amount: 47.30,
      spentAt: DateTime(2026, 9, 15, 12),
    ),
  ];

  final checks = [
    BalanceCheck(id: 1, walletId: 1, amount: 850, checkedAt: checkedAt),
    BalanceCheck(id: 2, walletId: 2, amount: 210, checkedAt: checkedAt),
  ];

  MonthSummary summaryOf(Month month) => MonthSummary.build(
    month: month,
    expenses: expenses,
    payments: payments,
    receipts: receipts,
    outflows: outflows,
    today: today,
  );

  List<WalletSummary> walletsOf(
    Month month, {
    List<BalanceCheck> informed = const <BalanceCheck>[],
  }) => WalletSummary.buildAll(
    month: month,
    wallets: [salary, voucher],
    receipts: receipts,
    payments: payments,
    occurrences: summaryOf(month).occurrences,
    checks: informed,
    outflows: outflows,
  );

  MonthReconciliation reconciliationOf(
    Month month, {
    List<BalanceCheck> informed = const <BalanceCheck>[],
  }) => MonthReconciliation.build(
    summary: summaryOf(month),
    wallets: walletsOf(month, informed: informed),
  );

  test('o saldo de cada carteira fecha com o que foi informado', () {
    final wallets = walletsOf(september, informed: checks);

    expect(wallets.first.checkAmount, 850);
    expect(wallets.first.receivedSinceCheck, 0);
    expect(wallets.first.spentSinceCheck, 99.90);
    expect(wallets.first.balance, 750.10);

    expect(wallets.last.spentSinceCheck, 47.30);
    expect(wallets.last.balance, 162.70);

    for (final wallet in wallets) {
      expect(
        wallet.balance,
        wallet.checkAmount + wallet.receivedSinceCheck - wallet.spentSinceCheck,
      );
    }
  });

  test('o mês diz quanto já estava no saldo informado', () {
    final summary = summaryOf(september);
    final reconciliation = reconciliationOf(september, informed: checks);

    expect(summary.totalReceived, 3800);
    expect(summary.totalSpent, 1561.20);
    expect(reconciliation.receivedBeforeCheck, 3800);
    expect(reconciliation.spentBeforeCheck, 1414);
    expect(reconciliation.balanceChange, isNull);
    expect(reconciliation.isEmpty, isFalse);
    expect(
      reconciliation.coveringChecks.map((covering) => covering.wallet.name),
      ['Salário', 'VR'],
    );
  });

  test('sem saldo informado no mês, o mês diz o que somou ao saldo', () {
    final summary = summaryOf(september);
    final reconciliation = reconciliationOf(september);

    expect(reconciliation.receivedBeforeCheck, 0);
    expect(reconciliation.spentBeforeCheck, 0);
    expect(reconciliation.coveringChecks, isEmpty);
    expect(reconciliation.balanceChange, 2238.80);
    expect(
      reconciliation.balanceChange,
      summary.totalReceived - summary.totalSpent,
    );
  });

  test('o mês sem lançamento nenhum fica vazio', () {
    final reconciliation = MonthReconciliation.build(
      summary: MonthSummary.empty(october),
      wallets: const [],
    );

    expect(reconciliation.isEmpty, isTrue);
    expect(reconciliation.balanceChange, 0);
  });
}
