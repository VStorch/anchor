import 'package:flutter/material.dart';

/// A movement already happened, so the picker stops at today; the range is
/// built around the date it opens on, so a month far back on screen never
/// falls outside it.
Future<DateTime?> pickMovementDate(BuildContext context, DateTime initial) {
  final today = DateUtils.dateOnly(DateTime.now());
  final day = DateUtils.dateOnly(initial);
  final start = day.isAfter(today) ? today : day;

  return showDatePicker(
    context: context,
    initialDate: start,
    firstDate: DateTime(start.year - 5),
    lastDate: today,
  );
}
