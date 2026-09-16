import '../../cards/models/card_invoice.dart';
import '../../cards/models/credit_card.dart';

/// What the Carteiras tab says about a card: the invoice a purchase made
/// today lands on — or the one of the month on screen — plus the older
/// invoices still waiting to be paid.
class CardOverview {
  const CardOverview({
    required this.card,
    required this.shown,
    required this.isOpenInvoice,
    this.pending = const <CardInvoice>[],
  });

  final CreditCard card;
  final CardInvoice shown;

  /// With purchases, unpaid and older than [shown]; the oldest first.
  final List<CardInvoice> pending;

  /// [shown] is the invoice `CreditCard.invoiceMonthFor(today)` points at.
  final bool isOpenInvoice;

  double get amount => shown.amount;
}
