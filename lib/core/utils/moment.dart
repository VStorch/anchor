/// The instant a movement picked by day is stored with: today keeps the
/// current time, so it lands after a balance checked earlier today; any other
/// day is noon, before a check informed for that same day.
DateTime stampFor(DateTime day, {DateTime? now}) {
  final current = now ?? DateTime.now();
  if (isSameDay(day, current)) return current;
  return DateTime(day.year, day.month, day.day, 12);
}

DateTime endOfDay(DateTime day) =>
    DateTime(day.year, day.month, day.day, 23, 59, 59, 999);

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
