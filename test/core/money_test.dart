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

  group('sem o símbolo', () {
    test('a célula da tabela mostra só o número', () {
      expect(formatMoneyInput(1100, symbol: false), '1.100,00');
    });

    test('digitar na célula não põe o R\$ de volta', () {
      const formatter = MoneyInputFormatter(symbol: false);
      final typed = formatter.formatEditUpdate(
        const TextEditingValue(
          text: '1.100,0',
          selection: TextSelection.collapsed(offset: 7),
        ),
        const TextEditingValue(
          text: '1.100,05',
          selection: TextSelection.collapsed(offset: 8),
        ),
      );
      expect(typed.text, '1.100,05');
      expect(parseMoney(typed.text), 1100.05);
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

    test('mantém o sinal já presente só no campo com sinal', () {
      const signed = MoneyInputFormatter(allowNegative: true);
      final typed = signed.formatEditUpdate(
        const TextEditingValue(text: '-'),
        const TextEditingValue(text: '-5'),
      );
      expect(typed.text, r'-R$ 5');
      final erased = signed.formatEditUpdate(
        const TextEditingValue(text: r'-R$ 5'),
        const TextEditingValue(text: r'-R$ '),
      );
      expect(erased.text, '-');
      expect(typeKeys('5', from: '-'), r'R$ 5');
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

  group('MoneyInputFormatter ao colar e editar no meio', () {
    const formatter = MoneyInputFormatter();
    const signed = MoneyInputFormatter(allowNegative: true);

    TextEditingValue edit(
      TextEditingValue before,
      String after, {
      int? cursor,
      MoneyInputFormatter using = formatter,
    }) => using.formatEditUpdate(
      before,
      TextEditingValue(
        text: after,
        selection: TextSelection.collapsed(offset: cursor ?? after.length),
      ),
    );

    TextEditingValue at(String text, int cursor) => TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: cursor),
    );

    TextEditingValue selectingAll(String text) => TextEditingValue(
      text: text,
      selection: TextSelection(baseOffset: 0, extentOffset: text.length),
    );

    test('colar "1.234,56" num campo vazio', () {
      expect(edit(TextEditingValue.empty, '1.234,56').text, r'R$ 1.234,56');
    });

    test('colar "1.234,56" sobre o valor selecionado', () {
      expect(edit(selectingAll(r'R$ 9'), '1.234,56').text, r'R$ 1.234,56');
    });

    test('colar "R\$ 10"', () {
      expect(edit(TextEditingValue.empty, r'R$ 10').text, r'R$ 10');
    });

    test('colar "-5" mantém o sinal só no campo com sinal', () {
      expect(edit(TextEditingValue.empty, '-5', using: signed).text, r'-R$ 5');
      expect(edit(TextEditingValue.empty, '-5').text, r'R$ 5');
      expect(edit(selectingAll(r'R$ 10'), '-5').text, r'R$ 5');
    });

    test('colar "12.5" lê o ponto como vírgula decimal', () {
      expect(edit(TextEditingValue.empty, '12.5').text, r'R$ 12,50');
      expect(edit(TextEditingValue.empty, '1.234').text, r'R$ 1.234');
    });

    test('inserir um dígito no meio junta os dígitos e mantém o cursor', () {
      final result = edit(at(r'R$ 1.234', 4), r'R$ 15.234', cursor: 5);
      expect(result.text, r'R$ 15.234');
      expect(result.selection.baseOffset, 5);
    });

    test('apagar um dígito no meio', () {
      final result = edit(at(r'R$ 1.234', 6), r'R$ 1.34', cursor: 5);
      expect(result.text, r'R$ 134');
      expect(result.selection.baseOffset, 4);
    });

    test('apagar a vírgula no meio junta reais e centavos', () {
      expect(edit(at(r'R$ 10,50', 6), r'R$ 1050', cursor: 5).text, r'R$ 1.050');
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
