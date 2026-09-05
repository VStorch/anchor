enum PayoutSchedule {
  dayOfMonth('day_of_month', 'Dia fixo'),
  businessDay('business_day', 'Dia útil');

  const PayoutSchedule(this.id, this.label);

  static PayoutSchedule fromId(String id) => values.firstWhere(
    (schedule) => schedule.id == id,
    orElse: () => dayOfMonth,
  );

  final String id;
  final String label;
}
