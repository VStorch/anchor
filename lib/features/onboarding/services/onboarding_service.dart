import '../../../core/state/data_changes.dart';
import '../../../core/utils/month.dart';
import '../../budget/services/budget_service.dart';
import '../../cards/models/credit_card.dart';
import '../../cards/repositories/card_repository.dart';
import '../../expenses/models/expense.dart';
import '../../expenses/models/expense_payment.dart';
import '../../expenses/models/expense_type.dart';
import '../../expenses/models/payable.dart';
import '../../expenses/repositories/expense_repository.dart';
import '../../wallets/models/balance_check.dart';
import '../../wallets/models/receipt.dart';
import '../../wallets/models/wallet.dart';
import '../../wallets/models/wallet_kind.dart';
import '../../wallets/repositories/wallet_repository.dart';
import '../models/onboarding_draft.dart';

class OnboardingService {
  OnboardingService({
    required WalletRepository wallets,
    required ExpenseRepository expenses,
    required CardRepository cards,
    required BudgetService budget,
    required DataChanges changes,
  }) : _wallets = wallets,
       _expenses = expenses,
       _cards = cards,
       _budget = budget,
       _changes = changes;

  final WalletRepository _wallets;
  final ExpenseRepository _expenses;
  final CardRepository _cards;
  final BudgetService _budget;
  final DataChanges _changes;

  /// Someone who already registered anything never sees the first run, even
  /// with no flag saved (an update from a version without onboarding).
  Future<bool> needsOnboarding(DateTime now) async {
    final snapshot = await _budget.loadSnapshot(Month.fromDate(now), now: now);
    return snapshot.isBlank;
  }

  /// Writes the whole draft with a single reload at the end. The balance
  /// informed today is taken at [now], and what the user says had already
  /// happened this month (the pay, a bill) is dated inside it, so the
  /// balance they typed is the balance they see.
  Future<void> apply(OnboardingDraft draft, {required DateTime now}) =>
      _changes.hold(() async {
        final month = Month.fromDate(now);
        final walletIds = <IncomeDraft, int>{};
        for (final (index, income) in draft.incomes.indexed) {
          walletIds[income] = await _wallets.saveWalletWithPayouts(
            Wallet(
              name: income.displayName,
              kind: income.kind,
              colorIndex: index,
              createdAt: now,
              monthlyReserve: income.kind == WalletKind.salary
                  ? income.monthlyReserve
                  : null,
            ),
            payouts: [income.toPayout(createdAt: now)],
          );
        }

        final checkedAt = await _informBalances(draft, walletIds, now);

        final cardDraft = draft.card;
        if (cardDraft != null) {
          await _cards.saveCard(
            CreditCard(
              name: cardDraft.name.trim(),
              closingDay: cardDraft.closingDay!,
              dueDay: cardDraft.dueDay!,
              walletId: walletIds[cardDraft.payer],
              createdAt: now,
            ),
          );
        }

        final payerId = walletIds[draft.billPayer];
        for (final bill in draft.bills) {
          await _saveExpense(
            Expense(
              name: bill.name.trim(),
              type: ExpenseType.recurring,
              amount: bill.amount,
              dueDay: bill.dueDay!,
              startMonth: month,
              walletId: payerId,
              createdAt: now,
            ),
            paid: bill.isPastDueBy(now) && bill.paidThisMonth,
            checkedAt: checkedAt[payerId],
            now: now,
          );
        }
        for (final installment in draft.installments) {
          await _saveExpense(
            Expense(
              name: installment.name.trim(),
              type: ExpenseType.installment,
              amount: installment.amount,
              dueDay: installment.dueDay!,
              startMonth: month,
              totalInstallments: installment.total,
              settledInstallments: installment.settledInstallments,
              walletId: payerId,
              createdAt: now,
            ),
            paid: installment.isPastDueBy(now) && installment.paidThisMonth,
            checkedAt: checkedAt[payerId],
            now: now,
          );
        }
      });

  /// Returns when each wallet's balance was informed. This month's receipt
  /// is created the way the app would, then confirmed inside the balance or
  /// left predicted and marked as not there yet; with no balance it stays
  /// predicted, for the user to confirm.
  Future<Map<int, DateTime>> _informBalances(
    OnboardingDraft draft,
    Map<IncomeDraft, int> walletIds,
    DateTime now,
  ) async {
    await _wallets.registerDuePayouts(await _wallets.fetchWallets(), now: now);
    final receipts = await _wallets.fetchReceipts();
    final checkedAt = <int, DateTime>{};

    for (final income in draft.incomes) {
      final walletId = walletIds[income]!;
      final predicted = receipts
          .where((receipt) => receipt.walletId == walletId)
          .where((receipt) => receipt.isPredicted)
          .toList();
      final arrived = income.isDueBy(now) ? income.arrived : null;
      final balance = income.balanceToday;
      if (balance == null) continue;

      await _wallets.saveBalanceCheck(
        BalanceCheck(walletId: walletId, amount: balance, checkedAt: now),
        confirm: arrived == true ? predicted : const <Receipt>[],
        leftPending: arrived == false ? predicted : const <Receipt>[],
      );
      checkedAt[walletId] = now;
    }
    return checkedAt;
  }

  Future<void> _saveExpense(
    Expense expense, {
    required bool paid,
    required DateTime? checkedAt,
    required DateTime now,
  }) async {
    final id = await _expenses.saveExpense(expense);
    if (!paid) return;

    final occurrence = expense
        .copyWith(id: id)
        .occurrenceIn(expense.startMonth)!;
    await _expenses.savePayment(
      ExpensePayment.fromOrigin(
        expenseId: id,
        origin: (walletId: expense.walletId, outside: false),
        month: occurrence.month,
        amount: occurrence.amount,
        paidAt: occurrence.paidBefore(checkedAt ?? now, now: now),
      ),
    );
  }
}
