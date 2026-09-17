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

/// [symbol] false drops "R$ " for a narrow cell whose header already says
/// the column is in reais.
String formatMoneyInput(double value, {bool symbol = true}) {
  final cents = (value.abs() * 100).round();
  return _RawMoney(
    negative: value < 0 && cents > 0,
    reais: '${cents ~/ 100}',
    hasComma: true,
    cents: '${cents % 100}'.padLeft(2, '0'),
  ).displayWith(symbol: symbol);
}

bool coversAmount(double paid, double total) => paid >= total - 0.005;

bool sameAmount(double a, double b) => (a - b).abs() < 0.005;

/// Sums of doubles leave residue like -0.0000000001, which formats as
/// "-R$ 0,00"; derived totals go through here before anyone compares them.
double roundCents(double value) => (value * 100).round() / 100;

/// Reais first: digits grow the integer part until a comma (or a dot) is
/// typed, then up to two digits of cents follow. Typing or erasing at the end
/// works key by key; an edit in the middle joins the digits again (a dot is
/// never a decimal in our own text); a paste or a replaced selection is read
/// as someone else wrote it. The cursor keeps its distance from the end.
class MoneyInputFormatter extends TextInputFormatter {
  const MoneyInputFormatter({this.allowNegative = false, this.symbol = true});

  final bool allowNegative;
  final bool symbol;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final before = oldValue.text;
    final after = newValue.text;
    if (after.isEmpty) return const TextEditingValue();

    final _RawMoney raw;
    if (before.isEmpty || _coversAll(oldValue)) {
      raw = _RawMoney.external(after, allowNegative: allowNegative);
    } else if (after.startsWith(before) && _cursorAtEnd(newValue)) {
      raw = _RawMoney.parse(before, allowNegative: allowNegative)
        ..type(after.substring(before.length));
    } else if (before.startsWith(after) &&
        before.length - after.length == 1 &&
        _cursorAtEnd(oldValue)) {
      raw = _RawMoney.parse(before, allowNegative: allowNegative)..backspace();
    } else {
      raw = _RawMoney.edited(after, allowNegative: allowNegative);
    }

    final text = raw.displayWith(symbol: symbol);
    final cursor = newValue.selection.isValid
        ? newValue.selection.baseOffset
        : after.length;
    final offset = (text.length - (after.length - cursor)).clamp(
      0,
      text.length,
    );
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: offset),
    );
  }

  static bool _coversAll(TextEditingValue value) =>
      value.selection.isValid &&
      !value.selection.isCollapsed &&
      value.selection.start == 0 &&
      value.selection.end == value.text.length;

  static bool _cursorAtEnd(TextEditingValue value) =>
      !value.selection.isValid || value.selection.end == value.text.length;
}

class _RawMoney {
  _RawMoney({
    required this.negative,
    this.reais = '',
    this.hasComma = false,
    this.cents = '',
  });

  factory _RawMoney.parse(String formatted, {required bool allowNegative}) {
    final parts = formatted.replaceAll(RegExp(r'[^0-9,]'), '').split(',');
    return _RawMoney(
      negative: allowNegative && formatted.startsWith('-'),
      reais: parts.first,
      hasComma: parts.length > 1,
      cents: parts.length > 1 ? parts[1] : '',
    );
  }

  /// Pasted text: a comma is the decimal; with no comma, a dot followed by up
  /// to two digits at the end is the decimal and any other dot groups
  /// thousands.
  factory _RawMoney.external(String text, {required bool allowNegative}) {
    final negative = allowNegative && text.trimLeft().startsWith('-');
    final kept = text.replaceAll(RegExp(r'[^0-9,.]'), '');
    final String reais;
    final String? decimals;
    final comma = kept.indexOf(',');
    final dotDecimal = RegExp(r'\.(\d{0,2})$').firstMatch(kept);
    if (comma >= 0) {
      reais = kept.substring(0, comma);
      decimals = kept.substring(comma + 1);
    } else if (dotDecimal != null) {
      reais = kept.substring(0, dotDecimal.start);
      decimals = dotDecimal.group(1);
    } else {
      reais = kept;
      decimals = null;
    }

    final raw = _RawMoney(negative: negative)..type(_digits(reais));
    if (decimals == null) return raw;
    raw
      ..hasComma = true
      ..type(_digits(decimals));
    if (raw.cents.isNotEmpty) raw.cents = raw.cents.padRight(2, '0');
    return raw;
  }

  factory _RawMoney.edited(String text, {required bool allowNegative}) {
    final raw = _RawMoney(
      negative: allowNegative && text.trimLeft().startsWith('-'),
    );
    return raw..type(text.replaceAll('.', ''));
  }

  static String _digits(String text) => text.replaceAll(RegExp(r'[^0-9]'), '');

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

  String displayWith({required bool symbol}) {
    final sign = negative ? '-' : '';
    if (reais.isEmpty && !hasComma) return sign;

    final grouped = (reais.isEmpty ? '0' : reais).replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => '.',
    );
    return '$sign'
        '${symbol ? 'R\$ ' : ''}$grouped'
        '${hasComma ? ',$cents' : ''}';
  }
}
