import 'package:flutter/material.dart';

/// One arrow per direction everywhere money shows up (the Carteiras list,
/// the agenda, the sheets): down comes in, up goes out. Whether it already
/// happened is the colour's job (`MoneyColors`), never the icon's.
abstract final class MoneyIcons {
  static const IconData income = Icons.arrow_downward;
  static const IconData spending = Icons.arrow_upward;
  static const IconData check = Icons.tune;
}
