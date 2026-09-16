import '../../../core/utils/moment.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/month.dart';
import '../../cards/models/credit_card.dart';
import '../../expenses/models/expense.dart';
import '../../expenses/models/expense_month.dart';
import '../../expenses/models/expense_occurrence.dart';
import '../../expenses/models/expense_payment.dart';
import '../../wallets/models/balance_check.dart';
import '../../wallets/models/outflow.dart';
import '../../wallets/models/receipt.dart';
import '../../wallets/models/wallet.dart';
import '../../wallets/models/wallet_deletion_impact.dart';
import '../../cards/models/card_invoice.dart';
import 'card_overview.dart';
import 'month_forecast.dart';
import 'month_reconciliation.dart';
import 'month_summary.dart';
import 'wallet_summary.dart';

class BudgetSnapshot {
  const BudgetSnapshot({
    required this.summary,
    required this.walletSummaries,
    required this.expenses,
    required this.wallets,
    required this.receipts,
    required this.payments,
    this.cards = const <CreditCard>[],
    this.monthAmounts = const <ExpenseMonth>[],
    this.checks = const <BalanceCheck>[],
    this.outflows = const <Outflow>[],
    this.forecast,
    this.reconciliation = MonthReconciliation.empty,
  });

  factory BudgetSnapshot.empty(MonthSummary summary) => BudgetSnapshot(
    summary: summary,
    walletSummaries: const <WalletSummary>[],
    expenses: const <Expense>[],
    wallets: const <Wallet>[],
    receipts: const <Receipt>[],
    payments: const <ExpensePayment>[],
  );

  final MonthSummary summary;
  final List<WalletSummary> walletSummaries;
  final List<Expense> expenses;
  final List<Wallet> wallets;
  final List<Receipt> receipts;
  final List<ExpensePayment> payments;
  final List<CreditCard> cards;
  final List<ExpenseMonth> monthAmounts;
  final List<BalanceCheck> checks;
  final List<Outflow> outflows;
  final MonthForecast? forecast;

  /// How the month's Entrou and Saiu meet the balances the user informed.
  final MonthReconciliation reconciliation;

  bool get hasWallets => wallets.isNotEmpty;

  /// Nothing registered yet: a first run, not a user who emptied a month.
  bool get isBlank => wallets.isEmpty && expenses.isEmpty && cards.isEmpty;

  List<ExpensePayment> paymentsOf(int expenseId) =>
      payments.where((payment) => payment.expenseId == expenseId).toList();

  double totalPaidOf(int expenseId) => roundCents(
    paymentsOf(expenseId).fold(0, (total, payment) => total + payment.amount),
  );

  /// How many bills (expense and month) were paid, at least in part, with
  /// the wallet.
  int paymentCountOf(int walletId) => payments
      .where((payment) => payment.walletId == walletId)
      .map((payment) => (payment.expenseId, payment.month))
      .toSet()
      .length;

  WalletDeletionImpact deletionImpactOf(int walletId) => WalletDeletionImpact(
    receipts: receipts
        .where((receipt) => receipt.walletId == walletId)
        .where((receipt) => receipt.isConfirmed)
        .length,
    outflows: outflows.where((outflow) => outflow.walletId == walletId).length,
    checks: checks.where((check) => check.walletId == walletId).length,
    paidBills: paymentCountOf(walletId),
    plannedBills: expenses
        .where((expense) => expense.walletId == walletId)
        .where((expense) => expense.cardId == null)
        .length,
    cards: cards.where((card) => card.walletId == walletId).length,
  );

  double get walletsBalance => roundCents(
    walletSummaries.fold(0, (total, summary) => total + summary.balance),
  );

  /// What the calendar says already came in this month and still waits for
  /// the user to confirm, whatever month is on screen.
  double get awaitingConfirmation {
    final currentMonth = Month.fromDate(summary.today);
    return roundCents(
      receipts
          .where((receipt) => receipt.isPredicted)
          .where((receipt) => receipt.month == currentMonth)
          .fold(0, (total, receipt) => total + receipt.amount),
    );
  }

  WalletSummary? summaryFor(int? walletId) {
    if (walletId == null) return null;
    for (final summary in walletSummaries) {
      if (summary.wallet.id == walletId) return summary;
    }
    return null;
  }

  Wallet? walletById(int? id) => summaryFor(id)?.wallet;

  BalanceCheck? latestCheckOf(int walletId) =>
      summaryFor(walletId)?.latestCheck;

  BalanceCheck? checkOnDay(int walletId, DateTime day) {
    BalanceCheck? found;
    for (final check in checks) {
      if (check.walletId == walletId && isSameDay(check.checkedAt, day)) {
        found = check;
      }
    }
    return found;
  }

  /// The invoice of any month, built from the raw lists with the snapshot's
  /// own `today`, so an invoice outside the month on screen reads the same
  /// clock as the ones inside it.
  CardInvoice? invoiceOf(int cardId, Month month) =>
      _summaryOf(month).invoiceOf(cardId);

  ExpenseOccurrence? occurrenceOf(int expenseId, Month month) =>
      _summaryOf(month).occurrenceOf(expenseId);

  MonthSummary _summaryOf(Month month) => month == summary.month
      ? summary
      : MonthSummary.build(
          month: month,
          expenses: expenses,
          payments: payments,
          receipts: receipts,
          monthAmounts: monthAmounts,
          outflows: outflows,
          cards: cards,
          today: summary.today,
        );

  /// How far back an unpaid invoice is still worth showing on the card.
  static const int _pendingMonths = 12;

  List<CardOverview> get cardOverview {
    final byMonth = <String, MonthSummary>{};
    MonthSummary summaryOf(Month month) =>
        byMonth.putIfAbsent(month.key, () => _summaryOf(month));

    final isCurrentMonth = summary.month == Month.fromDate(summary.today);

    return [
      for (final card in cards)
        if (card.id case final cardId?)
          _overviewOf(cardId, card, summaryOf, isCurrentMonth),
    ];
  }

  CardOverview _overviewOf(
    int cardId,
    CreditCard card,
    MonthSummary Function(Month) summaryOf,
    bool isCurrentMonth,
  ) {
    final openMonth = card.invoiceMonthFor(summary.today);
    final shownMonth = isCurrentMonth ? openMonth : summary.month;
    final pending = <CardInvoice>[];

    if (isCurrentMonth) {
      for (
        var month = shownMonth.addMonths(-_pendingMonths);
        month < shownMonth;
        month = month.next
      ) {
        final invoice = summaryOf(month).invoiceOf(cardId)!;
        if (invoice.items.isNotEmpty && !invoice.isPaid) pending.add(invoice);
      }
    }

    return CardOverview(
      card: card,
      shown: summaryOf(shownMonth).invoiceOf(cardId)!,
      pending: pending,
      isOpenInvoice: shownMonth == openMonth,
    );
  }

  CreditCard? cardById(int? id) {
    if (id == null) return null;
    for (final card in cards) {
      if (card.id == id) return card;
    }
    return null;
  }
}
