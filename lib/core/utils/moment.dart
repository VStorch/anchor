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

/// A check informed for a past day is taken at the end of it, so it has no
/// hour worth showing.
bool closesDay(DateTime at) => at.isAtSameMomentAs(endOfDay(at));

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Which side of a balance check a movement on the same day falls.
enum CheckSide { before, after }

/// Only a movement on the day of the latest check can land on either side of
/// it; a check that closes its day leaves nothing after it on that day.
bool needsCheckSide(DateTime day, DateTime? checkedAt) =>
    checkedAt != null &&
    isSameDay(day, checkedAt) &&
    isSameDay(checkedAt.add(_aroundCheck), checkedAt);

/// A second before or after the check on its day; [stampFor] on any other.
DateTime stampAround(
  DateTime day, {
  DateTime? checkedAt,
  CheckSide side = CheckSide.after,
  DateTime? now,
}) {
  if (!needsCheckSide(day, checkedAt)) return stampFor(day, now: now);
  return side == CheckSide.before
      ? checkedAt!.subtract(_aroundCheck)
      : checkedAt!.add(_aroundCheck);
}

CheckSide sideOf(DateTime at, DateTime checkedAt) =>
    at.isAfter(checkedAt) ? CheckSide.after : CheckSide.before;

const Duration _aroundCheck = Duration(seconds: 1);
