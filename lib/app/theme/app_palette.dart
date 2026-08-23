import 'package:flutter/material.dart';

abstract final class AppPalette {
  static const Color seed = Color(0xFF1B7F4C);
  static const Color deep = Color(0xFF0E4F31);
  static const Color moss = Color(0xFF2E9E5B);
  static const Color sage = Color(0xFF6FBF8F);
  static const Color mint = Color(0xFF9FD9B8);
  static const Color lime = Color(0xFF7FB069);
  static const Color pine = Color(0xFF14634A);
  static const Color teal = Color(0xFF12897B);

  static const List<Color> wallets = <Color>[
    seed,
    moss,
    teal,
    lime,
    deep,
    sage,
    pine,
    mint,
  ];

  static Color walletColorAt(int index) =>
      wallets[index.abs() % wallets.length];
}
