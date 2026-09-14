import 'package:anchor/core/utils/money.dart';
import 'package:anchor/core/utils/month.dart';
import 'package:anchor/features/budget/models/month_summary.dart';
import 'package:anchor/features/budget/models/wallet_summary.dart';
import 'package:anchor/features/cards/models/card_invoice.dart';
import 'package:anchor/features/cards/models/credit_card.dart';
import 'package:anchor/features/expenses/models/expense.dart';
import 'package:anchor/features/expenses/models/expense_month.dart';
import 'package:anchor/features/expenses/models/expense_payment.dart';
import 'package:anchor/features/expenses/models/expense_type.dart';
import 'package:anchor/features/wallets/models/balance_check.dart';
import 'package:anchor/features/wallets/models/outflow.dart';
import 'package:anchor/features/wallets/models/payout.dart';
import 'package:anchor/features/wallets/models/receipt.dart';
import 'package:anchor/features/wallets/models/receipt_status.dart';
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
    payouts: [
      Payout(
        walletId: id,
        label: 'Entrada',
        amount: monthly,
        day: 5,
        createdAt: DateTime(2026),
      ),
    ],
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

  group('saldo informado', () {
    const september = Month(2026, 9);
    final salaryPayout = Receipt(
      walletId: 1,
      payoutId: 1,
      month: september,
      amount: 3200,
      receivedAt: DateTime(2026, 9, 8),
      status: ReceiptStatus.predicted,
    );
    final rent = Expense(
      id: 30,
      name: 'Aluguel',
      type: ExpenseType.recurring,
      amount: 1100,
      dueDay: 10,
      startMonth: september,
      walletId: 1,
      createdAt: DateTime(2026, 9, 1),
    );
    final informed = BalanceCheck(
      id: 1,
      walletId: 1,
      amount: 850,
      checkedAt: DateTime(2026, 9, 13, 18),
    );

    WalletSummary salaryOf({
      List<Receipt> receipts = const <Receipt>[],
      List<ExpensePayment> payments = const <ExpensePayment>[],
      List<Outflow> outflows = const <Outflow>[],
      List<BalanceCheck> checks = const <BalanceCheck>[],
    }) => WalletSummary.buildAll(
      month: september,
      wallets: [salary],
      receipts: receipts,
      payments: payments,
      occurrences: const [],
      checks: checks,
      outflows: outflows,
    ).single;

    test('a entrada prevista não entra no saldo nem no que entrou', () {
      final summary = MonthSummary.build(
        month: september,
        expenses: const [],
        payments: const [],
        receipts: [salaryPayout],
      );
      final wallet = salaryOf(receipts: [salaryPayout]);

      expect(summary.totalReceived, 0);
      expect(summary.unconfirmedReceipts, [salaryPayout]);
      expect(wallet.balance, 0);
      expect(wallet.receivedInMonth, 0);
      expect(wallet.unconfirmedInMonth, 1);
      expect(wallet.pendingConfirmationInMonth, 3200);
    });

    test('o saldo passa a ser o valor informado', () {
      final wallet = salaryOf(receipts: receipts, checks: [informed]);

      expect(wallet.balance, 850);
      expect(wallet.latestCheck, informed);
    });

    test('o que tem data anterior ao saldo informado não conta de novo', () {
      final rentPaid = ExpensePayment(
        expenseId: rent.id!,
        walletId: 1,
        month: september,
        amount: 1100,
        paidAt: DateTime(2026, 9, 10, 12),
      );
      final wallet = salaryOf(
        receipts: [salaryPayout.copyWith(status: ReceiptStatus.confirmed)],
        payments: [rentPaid],
        checks: [informed],
      );

      expect(wallet.balance, 850);
      expect(wallet.countsInBalance(rentPaid.paidAt), isFalse);
    });

    test('o que vem depois do saldo informado mexe nele', () {
      final wallet = salaryOf(
        payments: [
          ExpensePayment(
            expenseId: rent.id!,
            walletId: 1,
            month: september,
            amount: 1100,
            paidAt: DateTime(2026, 9, 13, 19),
          ),
        ],
        outflows: [
          Outflow(
            walletId: 1,
            description: 'Mercado',
            amount: 47.9,
            spentAt: DateTime(2026, 9, 14, 12),
          ),
        ],
        receipts: [
          Receipt(
            walletId: 1,
            month: september,
            amount: 200,
            receivedAt: DateTime(2026, 9, 20, 12),
          ),
        ],
        checks: [informed],
      );

      expect(wallet.balance, -97.9);
    });

    test('aceita um saldo negativo', () {
      final overdrawn = BalanceCheck(
        walletId: 1,
        amount: -320.45,
        checkedAt: DateTime(2026, 9, 13, 18),
      );

      expect(salaryOf(checks: [overdrawn]).balance, -320.45);
    });

    test('com dois saldos informados, vale o mais recente', () {
      final older = BalanceCheck(
        id: 2,
        walletId: 1,
        amount: 5000,
        checkedAt: DateTime(2026, 9, 2, 23, 59),
      );
      final outflowBetween = Outflow(
        walletId: 1,
        description: 'Farmácia',
        amount: 60,
        spentAt: DateTime(2026, 9, 5, 12),
      );

      final wallet = salaryOf(
        outflows: [outflowBetween],
        checks: [informed, older],
      );

      expect(wallet.latestCheck, informed);
      expect(wallet.balance, 850);
    });

    test('o saldo de outra carteira não interfere', () {
      final summaries = WalletSummary.buildAll(
        month: august,
        wallets: [salary, voucher],
        receipts: receipts,
        payments: payments,
        occurrences: buildSummary().occurrences,
        checks: [informed],
      );

      expect(summaries.first.balance, 850);
      expect(summaries.last.balance, 600);
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
        checks: const [],
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
        checks: const [],
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

  group('antes de a despesa existir no app', () {
    final rent = Expense(
      id: 9,
      name: 'Aluguel',
      type: ExpenseType.recurring,
      amount: 1200,
      dueDay: 10,
      startMonth: const Month(2026, 1),
      createdAt: DateTime(2026, 9, 13),
    );

    MonthSummary summaryOf(
      Expense expense,
      Month month, {
      List<ExpensePayment> payments = const <ExpensePayment>[],
    }) => MonthSummary.build(
      month: month,
      expenses: [expense],
      payments: payments,
      receipts: const <Receipt>[],
    );

    test('não cobra os meses anteriores ao cadastro', () {
      expect(summaryOf(rent, august).occurrences, isEmpty);
      expect(summaryOf(rent, august).totalPending, 0);
      expect(summaryOf(rent, const Month(2026, 9)).occurrences, hasLength(1));
    });

    test('mostra o mês anterior quando há pagamento lançado nele', () {
      final summary = summaryOf(
        rent,
        august,
        payments: [
          ExpensePayment(
            expenseId: 9,
            walletId: 1,
            month: august,
            amount: 1200,
            paidAt: DateTime(2026, 8, 10),
          ),
        ],
      );

      expect(summary.occurrences.single.isPaid, isTrue);
    });

    test('a avulsa lançada depois continua no mês escolhido', () {
      final late = Expense(
        id: 10,
        name: 'Conserto',
        type: ExpenseType.single,
        amount: 300,
        dueDay: 20,
        startMonth: august,
        createdAt: DateTime(2026, 9, 13),
      );

      expect(summaryOf(late, august).occurrences, hasLength(1));
    });
  });

  group('fatura de cartão', () {
    final nubank = CreditCard(
      id: 7,
      name: 'Nubank',
      closingDay: 3,
      dueDay: 12,
      walletId: 1,
      createdAt: DateTime(2026, 8),
    );

    Expense onCard(int id, String name, double amount, {int? cardId = 7}) =>
        Expense(
          id: id,
          name: name,
          type: ExpenseType.installment,
          amount: amount,
          dueDay: 12,
          startMonth: august,
          totalInstallments: 10,
          walletId: 1,
          cardId: cardId,
          createdAt: DateTime(2026, 8),
        );

    final purchases = [
      onCard(20, 'Geladeira', 300),
      onCard(21, 'Celular', 150),
      buildExpense(id: 22, type: ExpenseType.recurring, amount: 90),
    ];

    MonthSummary summaryWith({
      List<CreditCard> cards = const <CreditCard>[],
      List<ExpensePayment> payments = const <ExpensePayment>[],
    }) => MonthSummary.build(
      month: august,
      expenses: purchases,
      payments: payments,
      receipts: const <Receipt>[],
      cards: cards,
    );

    test('as compras do cartão viram uma linha só', () {
      final summary = summaryWith(cards: [nubank]);
      final invoice = summary.payables.whereType<CardInvoice>().single;

      expect(summary.payables, hasLength(2));
      expect(invoice.name, 'Fatura Nubank');
      expect(invoice.amount, 450);
      expect(invoice.dueDate, DateTime(2026, 8, 12));
    });

    test('os totais do mês não mudam com a fatura', () {
      expect(summaryWith(cards: [nubank]).totalExpenses, 540);
      expect(summaryWith().totalExpenses, 540);
    });

    test('a fatura só fica paga quando todas as compras estão pagas', () {
      ExpensePayment paid(int expenseId, double amount) => ExpensePayment(
        expenseId: expenseId,
        walletId: 1,
        month: august,
        amount: amount,
        paidAt: DateTime(2026, 8, 12),
      );

      final partly = summaryWith(cards: [nubank], payments: [paid(20, 300)]);
      final full = summaryWith(
        cards: [nubank],
        payments: [paid(20, 300), paid(21, 150)],
      );

      expect(partly.invoiceOf(7)!.isPartlyPaid, isTrue);
      expect(partly.invoiceOf(7)!.remaining, 150);
      expect(full.invoiceOf(7)!.isPaid, isTrue);
      expect(full.totalPaid, 450);
    });

    test('sem o cartão, as compras voltam a ser despesas soltas', () {
      final summary = summaryWith();

      expect(summary.payables, hasLength(3));
      expect(summary.invoices, isEmpty);
    });

    test('a compra paga a mais não quita a outra compra da fatura', () {
      final summary = summaryWith(
        cards: [nubank],
        payments: [
          ExpensePayment(
            expenseId: 20,
            walletId: 1,
            month: august,
            amount: 400,
            paidAt: DateTime(2026, 8, 12),
          ),
        ],
      );
      final invoice = summary.invoiceOf(7)!;

      expect(invoice.isPaid, isFalse);
      expect(invoice.remaining, 150);
      expect(summary.totalPending, 240);
      expect(invoice.settlement.single.$1.expense.id, 21);
      expect(invoice.settlement.single.$2, invoice.remaining);
    });
  });

  group('conta paga a mais', () {
    final bills = [
      buildExpense(id: 1, type: ExpenseType.recurring, amount: 100),
      buildExpense(id: 2, type: ExpenseType.recurring, amount: 100),
    ];

    MonthSummary buildOverpaid() => MonthSummary.build(
      month: august,
      expenses: bills,
      payments: [
        ExpensePayment(
          expenseId: 1,
          walletId: 1,
          month: august,
          amount: 200,
          paidAt: DateTime(2026, 8, 10),
        ),
      ],
      receipts: const <Receipt>[],
    );

    test('não compensa a conta que ficou em aberto', () {
      final summary = buildOverpaid();

      expect(summary.totalPaid, 200);
      expect(summary.totalPending, 100);
      expect(summary.paidRatio, 0.5);
    });
  });

  group('centavos de arredondamento', () {
    final bill = [buildExpense(id: 1, type: ExpenseType.single, amount: 0.8)];
    final splitPayments = [
      for (final amount in [0.7, 0.1])
        ExpensePayment(
          expenseId: 1,
          walletId: 1,
          month: august,
          amount: amount,
          paidAt: DateTime(2026, 8, 10),
        ),
    ];
    final credit = [
      Receipt(
        walletId: 1,
        month: august,
        amount: 0.8,
        receivedAt: DateTime(2026, 8, 5),
      ),
    ];

    MonthSummary buildCents() => MonthSummary.build(
      month: august,
      expenses: bill,
      payments: splitPayments,
      receipts: credit,
    );

    test('a conta quitada em partes não fica com resto a pagar', () {
      final summary = buildCents();

      expect(summary.occurrenceOf(1)!.remaining, 0);
      expect(summary.totalPending, 0);
    });

    test('o saldo zerado não fica negativo', () {
      final summary = buildCents();
      final wallet = WalletSummary.buildAll(
        month: august,
        wallets: [salary],
        receipts: credit,
        payments: splitPayments,
        checks: const [],
        occurrences: summary.occurrences,
      ).single;

      expect(summary.balance.isNegative, isFalse);
      expect(wallet.balance.isNegative, isFalse);
      expect(wallet.balance, 0);
      expect(wallet.pendingInMonth, 0);
    });

    test('entradas em partes gastas por inteiro não deixam saldo negativo', () {
      final partReceipts = [
        for (final amount in [0.7, 0.1])
          Receipt(
            walletId: 1,
            month: august,
            amount: amount,
            receivedAt: DateTime(2026, 8, 5),
          ),
      ];
      final wholePayment = [
        ExpensePayment(
          expenseId: 1,
          walletId: 1,
          month: august,
          amount: 0.8,
          paidAt: DateTime(2026, 8, 10),
        ),
      ];
      final summary = MonthSummary.build(
        month: august,
        expenses: bill,
        payments: wholePayment,
        receipts: partReceipts,
      );
      final wallet = WalletSummary.buildAll(
        month: august,
        wallets: [salary],
        receipts: partReceipts,
        payments: wholePayment,
        checks: const [],
        occurrences: summary.occurrences,
      ).single;

      expect(summary.balance.isNegative, isFalse);
      expect(wallet.balance.isNegative, isFalse);
    });
  });

  group('pagamento fora da regra atual', () {
    final ended = Expense(
      id: 7,
      name: 'Academia',
      type: ExpenseType.recurring,
      amount: 120,
      dueDay: 10,
      startMonth: const Month(2026, 6),
      endMonth: const Month(2026, 7),
      walletId: 1,
      createdAt: DateTime(2026, 6),
    );
    final augustPayments = [
      ExpensePayment(
        expenseId: 7,
        walletId: 1,
        month: august,
        amount: 80,
        paidAt: DateTime(2026, 8, 10),
      ),
      ExpensePayment(
        expenseId: 7,
        walletId: 2,
        month: august,
        amount: 40,
        paidAt: DateTime(2026, 8, 11),
      ),
      ExpensePayment(
        expenseId: 1,
        walletId: 1,
        month: august,
        amount: 500,
        paidAt: DateTime(2026, 8, 10),
      ),
    ];
    final outflows = [
      Outflow(
        walletId: 1,
        description: 'Mercado',
        amount: 47.9,
        spentAt: DateTime(2026, 8, 12),
      ),
    ];

    MonthSummary buildWithEnded() => MonthSummary.build(
      month: august,
      expenses: [...expenses, ended],
      payments: augustPayments,
      receipts: receipts,
      outflows: outflows,
    );

    test('continua no mês, marcado como fora da regra e pago', () {
      final occurrence = buildWithEnded().occurrenceOf(7)!;

      expect(occurrence.offRule, isTrue);
      expect(occurrence.amount, 120);
      expect(occurrence.isPaid, isTrue);
      expect(occurrence.installmentNumber, isNull);
    });

    test('soma no que saiu e não muda o que falta pagar', () {
      final summary = buildWithEnded();
      final withoutEnded = MonthSummary.build(
        month: august,
        expenses: expenses,
        payments: augustPayments,
        receipts: receipts,
        outflows: outflows,
      );

      expect(summary.totalExpenses, withoutEnded.totalExpenses + 120);
      expect(summary.totalPending, withoutEnded.totalPending);
      expect(summary.totalSpent, 667.9);
      expect(
        roundCents(summary.totalSpent - summary.totalOutflows),
        roundCents(
          augustPayments.fold<double>(
            0,
            (sum, payment) => sum + payment.amount,
          ),
        ),
      );
    });

    test('o mês sem pagamento não ganha a ocorrência', () {
      final summary = MonthSummary.build(
        month: august,
        expenses: [ended],
        payments: const [],
        receipts: const [],
      );

      expect(summary.occurrences, isEmpty);
    });

    test('o valor do mês registrado vale sobre a soma paga', () {
      final summary = MonthSummary.build(
        month: august,
        expenses: [ended],
        payments: augustPayments.take(1).toList(),
        receipts: const [],
        monthAmounts: [
          const ExpenseMonth(expenseId: 7, month: august, amount: 150),
        ],
      );

      final occurrence = summary.occurrenceOf(7)!;
      expect(occurrence.amount, 150);
      expect(occurrence.remaining, 70);
    });
  });

  group('pago com outro dinheiro', () {
    final outside = ExpensePayment(
      expenseId: 1,
      month: august,
      amount: 500,
      paidAt: DateTime(2026, 8, 10),
      settledOutside: true,
    );

    MonthSummary buildOutside() => MonthSummary.build(
      month: august,
      expenses: expenses,
      payments: [outside],
      receipts: receipts,
    );

    test('quita a conta sem entrar no que saiu', () {
      final summary = buildOutside();

      expect(summary.occurrenceOf(1)!.isPaid, isTrue);
      expect(summary.occurrenceOf(1)!.paidFromWallets, 0);
      expect(summary.totalPaid, 500);
      expect(summary.totalPending, 500);
      expect(summary.totalSpent, 0);
      expect(summary.balance, 3600);
    });

    test('não mexe no saldo nem no gasto da carteira', () {
      final wallet = WalletSummary.buildAll(
        month: august,
        wallets: [salary],
        receipts: receipts,
        payments: [outside],
        occurrences: buildOutside().occurrences,
        checks: const [],
      ).single;

      expect(wallet.balance, 6000);
      expect(wallet.spentInMonth, 0);
    });
  });
}
