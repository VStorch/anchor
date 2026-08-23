import 'package:anchor/core/utils/money.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseMoney', () {
    test('lê apenas os dígitos como centavos', () {
      expect(parseMoney(r'R$ 1.234,56'), 1234.56);
      expect(parseMoney('7'), 0.07);
      expect(parseMoney(''), 0);
    });
  });

  group('MoneyInputFormatter', () {
    final formatter = MoneyInputFormatter();

    TextEditingValue format(String previous, String typed) =>
        formatter.formatEditUpdate(
          TextEditingValue(text: previous),
          TextEditingValue(text: typed),
        );

    test('formata a digitação em centavos', () {
      expect(format('', '1').text, contains('0,01'));
      expect(format('', '12345').text, contains('123,45'));
    });

    test('esvazia quando não há dígitos', () {
      expect(format('R\$ 1,00', '').text, isEmpty);
    });

    test('ignora entradas acima do limite de dígitos', () {
      final result = format(r'R$ 1,00', '1234567890123');
      expect(result.text, contains('1,00'));
    });
  });
}
