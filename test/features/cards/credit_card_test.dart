import 'package:anchor/core/utils/month.dart';
import 'package:anchor/features/cards/models/credit_card.dart';
import 'package:flutter_test/flutter_test.dart';

CreditCard card({required int closingDay, required int dueDay}) => CreditCard(
  name: 'Nubank',
  closingDay: closingDay,
  dueDay: dueDay,
  createdAt: DateTime(2026),
);

void main() {
  group('fatura em que a compra cai', () {
    final closesThenDue = card(closingDay: 3, dueDay: 10);
    final dueBeforeClosing = card(closingDay: 25, dueDay: 5);

    test('antes do fechamento entra na fatura que vence no mesmo mês', () {
      expect(
        closesThenDue.invoiceMonthFor(DateTime(2026, 9, 2)),
        const Month(2026, 9),
      );
    });

    test('no dia do fechamento ainda entra na fatura atual', () {
      expect(
        closesThenDue.invoiceMonthFor(DateTime(2026, 9, 3)),
        const Month(2026, 9),
      );
    });

    test('depois do fechamento vai para a fatura seguinte', () {
      expect(
        closesThenDue.invoiceMonthFor(DateTime(2026, 9, 4)),
        const Month(2026, 10),
      );
    });

    test('vencimento antes do fechamento empurra para o mês seguinte', () {
      expect(
        dueBeforeClosing.invoiceMonthFor(DateTime(2026, 9, 20)),
        const Month(2026, 10),
      );
      expect(
        dueBeforeClosing.invoiceMonthFor(DateTime(2026, 9, 26)),
        const Month(2026, 11),
      );
    });

    test('atravessa o ano', () {
      expect(
        closesThenDue.invoiceMonthFor(DateTime(2026, 12, 20)),
        const Month(2027, 1),
      );
    });
  });
}
