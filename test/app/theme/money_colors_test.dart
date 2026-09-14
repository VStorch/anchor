import 'package:anchor/app/theme/app_theme.dart';
import 'package:anchor/app/theme/money_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

double _contrast(Color a, Color b) {
  final lighter = a.computeLuminance() > b.computeLuminance() ? a : b;
  final darker = identical(lighter, a) ? b : a;
  return (lighter.computeLuminance() + 0.05) /
      (darker.computeLuminance() + 0.05);
}

void main() {
  for (final (name, theme) in [
    ('claro', AppTheme.light()),
    ('escuro', AppTheme.dark()),
  ]) {
    test('as cores de dinheiro são legíveis no tema $name', () {
      final colors = theme.extension<MoneyColors>()!;
      final scheme = theme.colorScheme;

      for (final background in [
        scheme.surface,
        scheme.surfaceContainerLow,
        theme.scaffoldBackgroundColor,
      ]) {
        for (final color in [
          colors.income,
          colors.spending,
          colors.neutral,
          colors.predicted,
        ]) {
          expect(_contrast(color, background), greaterThanOrEqualTo(4.5));
        }
      }
    });
  }
}
