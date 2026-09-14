import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

final NumberFormat _currency = NumberFormat.currency(
  locale: 'pt_BR',
  symbol: r'R$',
);

String formatMoney(double value) => _currency.format(value);

double parseMoney(String text) {
  final negative = text.trimLeft().startsWith('-');
  final parts = text.replaceAll(RegExp(r'[^0-9,]'), '').split(',');
  final reais = parts.first;
  final cents = parts.length > 1 ? parts[1] : '';
  if (reais.isEmpty && cents.isEmpty) return 0;

  final totalCents =
      int.parse(reais.isEmpty ? '0' : reais) * 100 +
      int.parse(cents.padRight(2, '0').substring(0, 2));
  if (totalCents == 0) return 0;
  return (negative ? -totalCents : totalCents) / 100;
}

String formatMoneyInput(double value) {
  final cents = (value.abs() * 100).round();
  return _RawMoney(
    negative: value < 0 && cents > 0,
    reais: '${cents ~/ 100}',
    hasComma: true,
    cents: '${cents % 100}'.padLeft(2, '0'),
  ).display;
}

bool coversAmount(double paid, double total) => paid >= total - 0.005;

bool sameAmount(double a, double b) => (a - b).abs() < 0.005;

/// Sums of doubles leave residue like -0.0000000001, which formats as
/// "-R$ 0,00"; derived totals go through here before anyone compares them.
double roundCents(double value) => (value * 100).round() / 100;

/// Reais first: digits grow the integer part until a comma (or a dot) is
/// typed, then up to two digits of cents follow. Nothing is filled in while
/// typing, and the cursor stays at the end.
class MoneyInputFormatter extends TextInputFormatter {
  const MoneyInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final before = oldValue.text;
    final after = newValue.text;
    if (after.isEmpty) return const TextEditingValue();

    final _RawMoney raw;
    if (after.startsWith(before)) {
      raw = _RawMoney.parse(before)..type(after.substring(before.length));
    } else if (before.startsWith(after)) {
      raw = _RawMoney.parse(before)..backspace();
    } else {
      raw = _RawMoney.typed(after);
    }

    final text = raw.display;
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

class _RawMoney {
  _RawMoney({
    required this.negative,
    this.reais = '',
    this.hasComma = false,
    this.cents = '',
  });

  factory _RawMoney.parse(String formatted) {
    final parts = formatted.replaceAll(RegExp(r'[^0-9,]'), '').split(',');
    return _RawMoney(
      negative: formatted.startsWith('-'),
      reais: parts.first,
      hasComma: parts.length > 1,
      cents: parts.length > 1 ? parts[1] : '',
    );
  }

  factory _RawMoney.typed(String text) {
    final raw = _RawMoney(negative: text.trimLeft().startsWith('-'));
    return raw..type(text.contains(',') ? text.replaceAll('.', '') : text);
  }

  static const int _maxReaisDigits = 12;

  final bool negative;
  String reais;
  bool hasComma;
  String cents;

  void type(String characters) {
    for (final character in characters.split('')) {
      if (character == ',' || character == '.') {
        hasComma = true;
      } else if (RegExp(r'[0-9]').hasMatch(character)) {
        _typeDigit(character);
      }
    }
  }

  void _typeDigit(String digit) {
    if (hasComma) {
      if (cents.length < 2) cents += digit;
    } else if (reais == '0') {
      reais = digit;
    } else if (reais.length < _maxReaisDigits) {
      reais += digit;
    }
  }

  void backspace() {
    if (cents.isNotEmpty) {
      cents = cents.substring(0, cents.length - 1);
    } else if (hasComma) {
      hasComma = false;
    } else if (reais.isNotEmpty) {
      reais = reais.substring(0, reais.length - 1);
    }
  }

  String get display {
    final sign = negative ? '-' : '';
    if (reais.isEmpty && !hasComma) return sign;

    final grouped = (reais.isEmpty ? '0' : reais).replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => '.',
    );
    return '$sign'
        'R\$ $grouped'
        '${hasComma ? ',$cents' : ''}';
  }
}
