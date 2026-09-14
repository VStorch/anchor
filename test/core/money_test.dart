import 'package:anchor/core/utils/money.dart';
import 'package:anchor/core/widgets/money_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseMoney', () {
    test('lê reais e centavos separados pela vírgula', () {
      expect(parseMoney(r'R$ 3.200,5'), 3200.5);
      expect(parseMoney(r'R$ 1.234,56'), 1234.56);
      expect(parseMoney(r'R$ 7'), 7);
      expect(parseMoney(''), 0);
    });

    test('lê o sinal negativo', () {
      expect(parseMoney(r'-R$ 12,00'), -12);
      expect(parseMoney('-'), 0);
    });
  });

  group('formatMoneyInput', () {
    test('entra no modo centavos com dois dígitos', () {
      expect(formatMoneyInput(3200), r'R$ 3.200,00');
      expect(formatMoneyInput(47.9), r'R$ 47,90');
      expect(formatMoneyInput(-12), r'-R$ 12,00');
    });
  });

  group('MoneyInputFormatter', () {
    const formatter = MoneyInputFormatter();

    String typeKeys(String keys, {String from = ''}) {
      var text = from;
      for (final key in keys.split('')) {
        text = formatter
            .formatEditUpdate(
              TextEditingValue(text: text),
              TextEditingValue(text: '$text$key'),
            )
            .text;
      }
      return text;
    }

    String backspace(String text) => formatter
        .formatEditUpdate(
          TextEditingValue(text: text),
          TextEditingValue(text: text.substring(0, text.length - 1)),
        )
        .text;

    test('digita reais primeiro', () {
      expect(typeKeys('3200'), r'R$ 3.200');
      expect(parseMoney(typeKeys('3200')), 3200);
    });

    test('a vírgula abre os centavos, sem completar', () {
      expect(typeKeys('3200,5'), r'R$ 3.200,5');
      expect(parseMoney(typeKeys('3200,5')), 3200.5);
      expect(typeKeys('1,999'), r'R$ 1,99');
    });

    test('o ponto vira vírgula, uma vez só', () {
      expect(typeKeys('47.90'), r'R$ 47,90');
      expect(typeKeys('47,.,9'), r'R$ 47,9');
    });

    test('o backspace apaga o último caractere, a vírgula inclusive', () {
      expect(backspace(r'R$ 47,9'), r'R$ 47,');
      expect(backspace(r'R$ 47,'), r'R$ 47');
      expect(backspace(r'R$ 1.000'), r'R$ 100');
      expect(backspace(r'R$ 4'), isEmpty);
    });

    test('limita os reais a 12 dígitos', () {
      expect(typeKeys('1234567890123'), r'R$ 123.456.789.012');
    });

    test('ignora o sinal digitado', () {
      expect(typeKeys('-5'), r'R$ 5');
    });

    test('mantém o sinal já presente', () {
      expect(typeKeys('5', from: '-'), r'-R$ 5');
      expect(backspace(r'-R$ 5'), '-');
    });

    test('texto substituído de uma vez é lido do zero', () {
      final result = formatter.formatEditUpdate(
        const TextEditingValue(text: r'R$ 150,00'),
        const TextEditingValue(text: '47,90'),
      );
      expect(result.text, r'R$ 47,90');
      expect(result.selection.baseOffset, result.text.length);
    });
  });

  group('MoneyField', () {
    Future<List<double>> pumpField(
      WidgetTester tester, {
      required bool allowNegative,
    }) async {
      final values = <double>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MoneyField(
              initialValue: 0,
              allowNegative: allowNegative,
              onChanged: values.add,
            ),
          ),
        ),
      );
      return values;
    }

    testWidgets('troca o sinal quando aceita negativo', (tester) async {
      final values = await pumpField(tester, allowNegative: true);

      await tester.enterText(find.byType(TextField), '12,50');
      await tester.tap(find.byTooltip('Trocar sinal'));
      await tester.pump();

      expect(find.text(r'-R$ 12,50'), findsOneWidget);
      expect(values.last, -12.5);

      await tester.tap(find.byTooltip('Trocar sinal'));
      await tester.pump();

      expect(find.text(r'R$ 12,50'), findsOneWidget);
      expect(values.last, 12.5);
    });

    testWidgets('sem aceitar negativo não oferece o sinal', (tester) async {
      final values = await pumpField(tester, allowNegative: false);

      await tester.enterText(find.byType(TextField), '-8');

      expect(find.byTooltip('Trocar sinal'), findsNothing);
      expect(find.text(r'R$ 8'), findsOneWidget);
      expect(values.last, 8);
    });
  });
}
