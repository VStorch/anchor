import '../../../core/state/data_changes.dart';
import '../../../core/state/month_selection.dart';
import '../../../core/utils/month.dart';
import '../../../core/viewmodels/reactive_view_model.dart';
import '../../budget/models/budget_snapshot.dart';
import '../../budget/models/month_summary.dart';
import '../../budget/models/wallet_summary.dart';
import '../../budget/services/budget_service.dart';
import '../models/receipt.dart';
import '../models/receipt_status.dart';
import '../models/wallet.dart';
import '../models/wallet_kind.dart';
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

  List<WalletSummary> summariesOf(WalletKind kind) =>
      summaries.where((summary) => summary.wallet.kind == kind).toList();

  List<Receipt> get monthReceipts => _snapshot.receipts
      .where(
        (receipt) => receipt.month == _monthSelection.current && receipt.counts,
      )
      .toList();

  bool get isEmpty => summaries.isEmpty;

  double get totalBalance =>
      summaries.fold(0, (total, summary) => total + summary.balance);

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

  Wallet? walletById(int id) => _snapshot.walletById(id);

  @override
  void dispose() {
    _monthSelection.removeListener(refresh);
    super.dispose();
  }
}
