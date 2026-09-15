/// What deleting a wallet takes with it (its receipts, outflows and balance
/// checks), what stays paid as money from outside ([paidBills]) and what is
/// left with no wallet ([plannedBills], [cards]).
class WalletDeletionImpact {
  const WalletDeletionImpact({
    required this.receipts,
    required this.outflows,
    required this.checks,
    required this.paidBills,
    required this.plannedBills,
    required this.cards,
  });

  final int receipts;
  final int outflows;
  final int checks;
  final int paidBills;
  final int plannedBills;
  final int cards;

  bool get isEmpty =>
      receipts + outflows + checks + paidBills + plannedBills + cards == 0;
}
