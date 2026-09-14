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

  DateTime get suggestedDate =>
      isCurrent ? DateTime.now() : dayOf(DateTime.now().day);

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

  DateTime businessDay(int position) {
    var found = 0;
    var lastBusinessDay = 1;

    for (var day = 1; day <= lengthInDays; day++) {
      final date = DateTime(year, month, day);
      if (date.weekday > DateTime.friday || BrazilianHolidays.isHoliday(date)) {
        continue;
      }
      lastBusinessDay = day;
      if (++found == position) return DateTime(year, month, day);
    }

    return DateTime(year, month, lastBusinessDay);
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
