import '../../../core/utils/month.dart';
import '../../cards/models/credit_card.dart';
import '../../expenses/models/expense.dart';
import '../../expenses/models/expense_type.dart';
import '../../wallets/models/outflow.dart';

/// Money a wallet spent day to day, outside the bills: what the reserve for
/// everyday spending is used up by and what its suggested average is made of.
class EverydaySpending {
  const EverydaySpending({
    required this.walletId,
    required this.amount,
    required this.at,
  });

  final int walletId;
  final double amount;
  final DateTime at;

  Month get month => Month.fromDate(at);

  /// Outflows, plus the one-off card purchases charged to the wallet that
  /// pays the card, on the day they were bought. A purchase in parcels was
  /// planned, so it is a bill and not everyday spending; one saved before
  /// the purchase day was recorded has no day to count on.
  static List<EverydaySpending> collect({
    required List<Outflow> outflows,
    required List<Expense> expenses,
    required List<CreditCard> cards,
  }) {
    final payerOf = <int, int>{
      for (final card in cards)
        if (card.id != null && card.walletId != null) card.id!: card.walletId!,
    };

    return [
      for (final outflow in outflows)
        EverydaySpending(
          walletId: outflow.walletId,
          amount: outflow.amount,
          at: outflow.spentAt,
        ),
      for (final expense in expenses)
        if (expense.type == ExpenseType.single &&
            expense.purchasedAt != null &&
            payerOf[expense.cardId] != null)
          EverydaySpending(
            walletId: payerOf[expense.cardId]!,
            amount: expense.amount,
            at: expense.purchasedAt!,
          ),
    ];
  }
}
