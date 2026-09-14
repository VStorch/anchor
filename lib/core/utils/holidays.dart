abstract final class BrazilianHolidays {
  static const List<(int, int, int)> _fixed = [
    (1, 1, 1),
    (4, 21, 1),
    (5, 1, 1),
    (9, 7, 1),
    (10, 12, 1),
    (11, 2, 1),
    (11, 15, 1),
    (11, 20, 2024),
    (12, 25, 1),
  ];

  static const List<int> _daysFromEaster = [-48, -47, -2, 60];

  /// Anonymous Gregorian algorithm (Meeus/Jones/Butcher).
  static DateTime easter(int year) {
    final a = year % 19;
    final b = year ~/ 100;
    final c = year % 100;
    final d = b ~/ 4;
    final e = b % 4;
    final f = (b + 8) ~/ 25;
    final g = (b - f + 1) ~/ 3;
    final h = (19 * a + b - d - g + 15) % 30;
    final i = c ~/ 4;
    final k = c % 4;
    final l = (32 + 2 * e + 2 * i - h - k) % 7;
    final m = (a + 11 * h + 22 * l) ~/ 451;
    final month = (h + l - 7 * m + 114) ~/ 31;
    final day = (h + l - 7 * m + 114) % 31 + 1;
    return DateTime(year, month, day);
  }

  static bool isHoliday(DateTime day) {
    final isFixed = _fixed.any(
      (holiday) =>
          holiday.$1 == day.month &&
          holiday.$2 == day.day &&
          day.year >= holiday.$3,
    );
    if (isFixed) return true;

    final easterDay = easter(day.year);
    return _daysFromEaster.any((offset) {
      final holiday = DateTime(
        easterDay.year,
        easterDay.month,
        easterDay.day + offset,
      );
      return holiday.month == day.month && holiday.day == day.day;
    });
  }
}
