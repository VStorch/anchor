import '../../../core/utils/money.dart';
import '../../wallets/models/balance_check.dart';
import '../../wallets/models/wallet.dart';
import 'month_summary.dart';
import 'wallet_summary.dart';

/// How the month's figures meet the balance the user informed: what part of
/// "Entrou" and "Saiu" was already inside an informed balance, and — only
/// when nothing was — how much the month moved that balance.
class MonthReconciliation {
  const MonthReconciliation({
    required this.receivedBeforeCheck,
    required this.spentBeforeCheck,
    required this.coveringChecks,
    required this.balanceChange,
    required this.isEmpty,
  });

  static MonthReconciliation build({
    required MonthSummary summary,
    required List<WalletSummary> wallets,
  }) {
    final covering = <({Wallet wallet, BalanceCheck check})>[];
    var received = 0.0;
    var spent = 0.0;

    for (final wallet in wallets) {
      if (!wallet.hasMovementBeforeCheck) continue;
      received += wallet.receivedInMonthBeforeCheck;
      spent += wallet.spentInMonthBeforeCheck;
      final check = wallet.latestCheck;
      if (check != null) {
        covering.add((wallet: wallet.wallet, check: check));
      }
    }

    final hasMovementBeforeCheck = received > 0 || spent > 0;
    return MonthReconciliation(
      receivedBeforeCheck: roundCents(received),
      spentBeforeCheck: roundCents(spent),
      coveringChecks: List.unmodifiable(covering),
      balanceChange: hasMovementBeforeCheck
          ? null
          : roundCents(summary.totalReceived - summary.totalSpent),
      isEmpty: summary.totalReceived == 0 && summary.totalSpent == 0,
    );
  }

  static const MonthReconciliation empty = MonthReconciliation(
    receivedBeforeCheck: 0,
    spentBeforeCheck: 0,
    coveringChecks: <({Wallet wallet, BalanceCheck check})>[],
    balanceChange: 0,
    isEmpty: true,
  );

  final double receivedBeforeCheck;
  final double spentBeforeCheck;

  /// The informed balances that already hold part of the month, one per
  /// wallet, so the note can name them.
  final List<({Wallet wallet, BalanceCheck check})> coveringChecks;

  /// What the month's entries did to the balance — only where no entry of
  /// the month is inside an informed balance, or it would count twice.
  final double? balanceChange;

  /// Nothing came in and nothing left in the month.
  final bool isEmpty;
}
