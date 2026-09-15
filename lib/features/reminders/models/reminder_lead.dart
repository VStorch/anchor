enum ReminderLead {
  sameDay('sameDay', 'No dia', [0]),
  dayBefore('dayBefore', '1 dia antes', [1]),
  both('both', 'Os dois', [1, 0]);

  const ReminderLead(this.id, this.label, this.daysAhead);

  final String id;
  final String label;
  final List<int> daysAhead;

  static ReminderLead fromId(String? id) =>
      values.firstWhere((lead) => lead.id == id, orElse: () => both);
}
