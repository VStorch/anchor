import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

final NumberFormat _currency = NumberFormat.currency(
  locale: 'pt_BR',
  symbol: r'R$',
);

String formatMoney(double value) => _currency.format(value);

double parseMoney(String text) {
  final digits = text.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty) return 0;
  return int.parse(digits) / 100;
}

bool coversAmount(double paid, double total) => paid >= total - 0.005;

bool sameAmount(double a, double b) => (a - b).abs() < 0.005;

/// Sums of doubles leave residue like -0.0000000001, which formats as
/// "-R$ 0,00"; derived totals go through here before anyone compares them.
double roundCents(double value) => (value * 100).round() / 100;

class MoneyInputFormatter extends TextInputFormatter {
  static const int _maxDigits = 12;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return const TextEditingValue();
    if (digits.length > _maxDigits) {
      digits = oldValue.text.replaceAll(RegExp(r'[^0-9]'), '');
      if (digits.isEmpty) return oldValue;
    }
    final formatted = formatMoney(int.parse(digits) / 100);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
