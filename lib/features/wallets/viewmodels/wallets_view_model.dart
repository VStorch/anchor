import '../../../core/state/data_changes.dart';
import '../../../core/state/month_selection.dart';
import '../../../core/utils/moment.dart';
import '../../../core/utils/month.dart';
import '../../../core/viewmodels/reactive_view_model.dart';
import '../../budget/models/budget_snapshot.dart';
import '../../cards/models/card_invoice.dart';
import '../../budget/models/month_summary.dart';
import '../../budget/models/wallet_summary.dart';
import '../../budget/services/budget_service.dart';
import '../models/balance_check.dart';
import '../models/outflow.dart';
import '../models/receipt.dart';
import '../models/receipt_status.dart';
import '../models/wallet.dart';
import '../models/wallet_kind.dart';
import '../models/wallet_movement.dart';
import '../repositories/wallet_repository.dart';

class WalletsViewModel extends ReactiveViewModel {
  WalletsViewModel({
    required BudgetService budgetService,
    required WalletRepository walletRepository,
    required MonthSelection monthSelection,
    required DataChanges changes,
  }) : _budgetService = budgetService,
       _walletRepository = walletRepository,
       _monthSelection = monthSelection,
       super(changes) {
    _monthSelection.addListener(refresh);
  }

  final BudgetService _budgetService;
  final WalletRepository _walletRepository;
  final MonthSelection _monthSelection;

  BudgetSnapshot _snapshot = BudgetSnapshot.empty(
    MonthSummary.empty(Month.current()),
  );

  Month get month => _monthSelection.current;

  List<WalletSummary> get summaries => _snapshot.walletSummaries;

  List<Wallet> get wallets => _snapshot.wallets;

  List<CardInvoice> get invoices => _snapshot.summary.invoices;

  List<WalletSummary> summariesOf(WalletKind kind) =>
      summaries.where((summary) => summary.wallet.kind == kind).toList();

  List<WalletMovement> get monthMovements {
    final month = _monthSelection.current;
    final movements = <WalletMovement>[
      for (final receipt in _snapshot.receipts)
        if (receipt.month == month && receipt.counts)
          WalletMovement.fromReceipt(
            receipt,
            title: receiptTitle(receipt),
            countsInBalance: _countsInBalance(
              receipt.walletId,
              receipt.receivedAt,
            ),
          ),
      for (final outflow in _snapshot.summary.outflows)
        WalletMovement.fromOutflow(
          outflow,
          countsInBalance: _countsInBalance(outflow.walletId, outflow.spentAt),
        ),
      for (final payment in _snapshot.payments)
        if (payment.month == month && payment.walletId != null)
          WalletMovement(
            date: payment.paidAt,
            title: _expenseName(payment.expenseId),
            walletId: payment.walletId!,
            amount: -payment.amount,
            countsInBalance: _countsInBalance(
              payment.walletId!,
              payment.paidAt,
            ),
          ),
      for (final check in _snapshot.checks)
        if (Month.fromDate(check.checkedAt) == month)
          WalletMovement.fromCheck(
            check,
            isLatest: _snapshot.latestCheckOf(check.walletId)?.id == check.id,
          ),
    ];

    movements.sort((a, b) => b.date.compareTo(a.date));
    return movements;
  }

  bool _countsInBalance(int walletId, DateTime at) =>
      _snapshot.summaryFor(walletId)?.countsInBalance(at) ?? true;

  String receiptTitle(Receipt receipt) {
    for (final payout in walletById(receipt.walletId)?.payouts ?? const []) {
      if (payout.id == receipt.payoutId) return payout.label;
    }
    return 'Entrada';
  }

  String _expenseName(int expenseId) {
    for (final expense in _snapshot.expenses) {
      if (expense.id == expenseId) return expense.name;
    }
    return 'Despesa';
  }

  bool get isEmpty => summaries.isEmpty;

  double get totalBalance => _snapshot.walletsBalance;

  double get monthlyIncome => summaries.fold(
    0,
    (total, summary) => total + summary.wallet.monthlyIncome,
  );

  @override
  Future<void> loadData() async {
    _snapshot = await _budgetService.loadSnapshot(_monthSelection.current);
  }

  void goToPreviousMonth() => _monthSelection.goToPrevious();

  void goToNextMonth() => _monthSelection.goToNext();

  void goToCurrentMonth() => _monthSelection.goToToday();

  Future<void> deleteWallet(Wallet wallet) =>
      _walletRepository.deleteWallet(wallet.id!);

  Future<void> registerReceipt({
    required Wallet wallet,
    required double amount,
    required DateTime receivedAt,
  }) => _walletRepository.saveReceipt(
    Receipt(
      walletId: wallet.id!,
      month: Month.fromDate(receivedAt),
      amount: amount,
      receivedAt: receivedAt,
    ),
  );

  Future<void> confirmReceipt(
    Receipt receipt, {
    required double amount,
    required DateTime receivedAt,
  }) => _walletRepository.saveReceipt(
    receipt.copyWith(
      amount: amount,
      receivedAt: receivedAt,
      status: ReceiptStatus.confirmed,
    ),
  );

  Future<void> discardReceipt(Receipt receipt) =>
      _walletRepository.discardReceipt(receipt);

  Future<void> saveOutflow({
    required Wallet wallet,
    Outflow? outflow,
    required String description,
    required double amount,
    required DateTime spentAt,
  }) => _walletRepository.saveOutflow(
    outflow?.copyWith(
          description: description,
          amount: amount,
          spentAt: spentAt,
        ) ??
        Outflow(
          walletId: wallet.id!,
          description: description,
          amount: amount,
          spentAt: spentAt,
        ),
  );

  Future<void> deleteOutflow(Outflow outflow) =>
      _walletRepository.deleteOutflow(outflow.id!);

  WalletSummary? summaryFor(int walletId) => _snapshot.summaryFor(walletId);

  /// Predicted receipts of this month that were due by [at] — the ones a
  /// balance informed at that moment may already contain.
  List<Receipt> dueUnconfirmedOf(Wallet wallet, DateTime at) {
    final currentMonth = Month.current();
    return _snapshot.receipts
        .where(
          (receipt) =>
              receipt.walletId == wallet.id &&
              receipt.isPredicted &&
              receipt.month == currentMonth &&
              !receipt.receivedAt.isAfter(at),
        )
        .toList()
      ..sort((a, b) => a.receivedAt.compareTo(b.receivedAt));
  }

  /// A check on a past day closes that day, so everything dated on it is
  /// inside the informed amount; a check for today is taken right now.
  static DateTime checkedAtFor(DateTime day, {DateTime? now}) {
    final current = now ?? DateTime.now();
    return isSameDay(day, current) ? current : endOfDay(day);
  }

  Future<void> saveBalanceCheck(
    Wallet wallet, {
    required double amount,
    required DateTime day,
    BalanceCheck? editing,
    List<Receipt> confirm = const <Receipt>[],
  }) {
    final checkedAt = editing != null && isSameDay(editing.checkedAt, day)
        ? editing.checkedAt
        : checkedAtFor(day);
    return _walletRepository.saveBalanceCheck(
      editing?.copyWith(amount: amount, checkedAt: checkedAt) ??
          BalanceCheck(
            walletId: wallet.id!,
            amount: amount,
            checkedAt: checkedAt,
          ),
      confirm: confirm,
    );
  }

  Future<void> deleteBalanceCheck(BalanceCheck check) =>
      _walletRepository.deleteBalanceCheck(check.id!);

  Wallet? walletById(int id) => _snapshot.walletById(id);

  @override
  void dispose() {
    _monthSelection.removeListener(refresh);
    super.dispose();
  }
}
