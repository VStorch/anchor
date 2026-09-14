import 'package:flutter/material.dart';

/// What a figure means, not how it is drawn: money in, money out, a figure
/// with no direction, and a forecast, which must never read as real money.
@immutable
class MoneyColors extends ThemeExtension<MoneyColors> {
  const MoneyColors({
    required this.income,
    required this.spending,
    required this.neutral,
    required this.predicted,
  });

  static const MoneyColors light = MoneyColors(
    income: Color(0xFF1B6B3E),
    spending: Color(0xFF9A3F12),
    neutral: Color(0xFF45514A),
    predicted: Color(0xFF3B5694),
  );

  static const MoneyColors dark = MoneyColors(
    income: Color(0xFF86D9A6),
    spending: Color(0xFFFFB38C),
    neutral: Color(0xFFC1CAC3),
    predicted: Color(0xFFAFC6FF),
  );

  static MoneyColors of(BuildContext context) =>
      Theme.of(context).extension<MoneyColors>() ??
      (Theme.of(context).brightness == Brightness.dark ? dark : light);

  final Color income;
  final Color spending;
  final Color neutral;
  final Color predicted;

  @override
  MoneyColors copyWith({
    Color? income,
    Color? spending,
    Color? neutral,
    Color? predicted,
  }) => MoneyColors(
    income: income ?? this.income,
    spending: spending ?? this.spending,
    neutral: neutral ?? this.neutral,
    predicted: predicted ?? this.predicted,
  );

  @override
  MoneyColors lerp(MoneyColors? other, double t) {
    if (other == null) return this;
    return MoneyColors(
      income: Color.lerp(income, other.income, t)!,
      spending: Color.lerp(spending, other.spending, t)!,
      neutral: Color.lerp(neutral, other.neutral, t)!,
      predicted: Color.lerp(predicted, other.predicted, t)!,
    );
  }
}
