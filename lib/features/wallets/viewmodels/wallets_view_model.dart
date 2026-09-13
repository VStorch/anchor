import '../../../core/state/data_changes.dart';
import '../../../core/state/month_selection.dart';
import '../../../core/utils/month.dart';
import '../../../core/viewmodels/reactive_view_model.dart';
import '../../budget/models/budget_snapshot.dart';
import '../../cards/models/card_invoice.dart';
import '../../budget/models/month_summary.dart';
import '../../budget/models/wallet_summary.dart';
import '../../budget/services/budget_service.dart';
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
          WalletMovement.fromReceipt(receipt, title: _receiptTitle(receipt)),
      for (final outflow in _snapshot.summary.outflows)
        WalletMovement.fromOutflow(outflow),
      for (final payment in _snapshot.payments)
        if (payment.month == month && payment.walletId != null)
          WalletMovement(
            date: payment.paidAt,
            title: _expenseName(payment.expenseId),
            walletId: payment.walletId!,
            amount: -payment.amount,
          ),
    ];

    movements.sort((a, b) => b.date.compareTo(a.date));
    return movements;
  }

  String _receiptTitle(Receipt receipt) {
    if (receipt.isAdjustment) return 'Ajuste de saldo';

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

  Future<void> adjustBalance(WalletSummary summary, double targetBalance) =>
      _walletRepository.adjustBalance(
        wallet: summary.wallet,
        currentBalance: summary.balance,
        targetBalance: targetBalance,
      );

  Wallet? walletById(int id) => _snapshot.walletById(id);

  @override
  void dispose() {
    _monthSelection.removeListener(refresh);
    super.dispose();
  }
}
