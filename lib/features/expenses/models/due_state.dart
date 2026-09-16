/// Where a bill stands against today: what the list, the dashboard and the
/// pay sheet read instead of comparing dates themselves.
enum DueState {
  paid,
  offRule,
  overdue,
  today,
  tomorrow,
  upcoming;

  bool get isDueToday => this == today;
}
