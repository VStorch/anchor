import '../../cards/models/credit_card.dart';
import 'wallet.dart';

/// Where a new spending came from, as the "Novo gasto" sheet reads it.
sealed class SpendingSource {
  const SpendingSource();
}

final class WalletSource extends SpendingSource {
  const WalletSource(this.wallet);

  final Wallet wallet;
}

final class CardSource extends SpendingSource {
  const CardSource(this.card);

  final CreditCard card;
}

/// Not money that already left: a bill with a due day.
final class BillSource extends SpendingSource {
  const BillSource();
}
