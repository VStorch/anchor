import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import 'holidays.dart';

@immutable
class Month implements Comparable<Month> {
  const Month(this.year, this.month);

  factory Month.fromDate(DateTime date) => Month(date.year, date.month);

  factory Month.current() => Month.fromDate(DateTime.now());

  factory Month.fromKey(String key) {
    final parts = key.split('-');
    return Month(int.parse(parts.first), int.parse(parts.last));
  }

  final int year;
  final int month;

  String get key => '$year-${month.toString().padLeft(2, '0')}';

  DateTime get firstDay => DateTime(year, month);

  int get lengthInDays => DateTime(year, month + 1, 0).day;

  String get label =>
      toBeginningOfSentenceCase(DateFormat.yMMMM('pt_BR').format(firstDay))!;

  bool get isCurrent => this == Month.current();

  /// A day inside this month for a new movement; never one still to come.
  DateTime get suggestedDate {
    final now = DateTime.now();
    return this < Month.fromDate(now) ? dayOf(now.day) : now;
  }

  Month addMonths(int amount) {
    final date = DateTime(year, month + amount);
    return Month(date.year, date.month);
  }

  Month get next => addMonths(1);

  Month get previous => addMonths(-1);

  int monthsSince(Month other) =>
      (year - other.year) * 12 + (month - other.month);

  DateTime dayOf(int dayOfMonth) =>
      DateTime(year, month, min(dayOfMonth, lengthInDays));

  /// Counts Monday to Friday, skipping national holidays. With
  /// [countSaturday] Saturdays count too (the CLT deadline), but a date that
  /// lands on one moves back to the bank business day before it.
  DateTime businessDay(int position, {bool countSaturday = false}) {
    final target = max(position, 1);
    final lastWeekday = countSaturday ? DateTime.saturday : DateTime.friday;
    var found = 0;
    var lastCounted = 1;

    for (var day = 1; day <= lengthInDays; day++) {
      if (!_counts(DateTime(year, month, day), lastWeekday)) continue;
      lastCounted = day;
      if (++found == target) break;
    }

    final date = DateTime(year, month, lastCounted);
    if (date.weekday != DateTime.saturday) return date;
    return _bankDayAround(lastCounted);
  }

  bool _counts(DateTime date, int lastWeekday) =>
      date.weekday <= lastWeekday && !BrazilianHolidays.isHoliday(date);

  DateTime _bankDayAround(int saturday) {
    for (var day = saturday - 1; day >= 1; day--) {
      final date = DateTime(year, month, day);
      if (_counts(date, DateTime.friday)) return date;
    }
    for (var day = saturday + 1; day <= lengthInDays; day++) {
      final date = DateTime(year, month, day);
      if (_counts(date, DateTime.friday)) return date;
    }
    return DateTime(year, month, saturday);
  }

  @override
  int compareTo(Month other) =>
      (year * 12 + month) - (other.year * 12 + other.month);

  bool operator <(Month other) => compareTo(other) < 0;

  bool operator <=(Month other) => compareTo(other) <= 0;

  bool operator >(Month other) => compareTo(other) > 0;

  bool operator >=(Month other) => compareTo(other) >= 0;

  @override
  bool operator ==(Object other) =>
      other is Month && other.year == year && other.month == month;

  @override
  int get hashCode => Object.hash(year, month);

  @override
  String toString() => key;
}
