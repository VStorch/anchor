import '../../../core/utils/money.dart';
import '../../expenses/models/payable.dart';
import 'reminder_lead.dart';

class DueReminder {
  const DueReminder({
    required this.id,
    required this.at,
    required this.title,
    required this.body,
  });

  factory DueReminder.forBills(
    DateTime due,
    int daysAhead,
    List<Payable> bills,
  ) {
    final total = bills.fold<double>(0, (sum, bill) => sum + bill.remaining);
    final names = bills.map((bill) => bill.name).toList();
    final when = daysAhead == 0 ? 'hoje' : 'amanhã';

    return DueReminder(
      id: idFor(due, daysAhead),
      at: DateTime(due.year, due.month, due.day - daysAhead, hourOfDay),
      title: bills.length == 1
          ? '${names.single} vence $when'
          : '${bills.length} contas vencem $when',
      body: bills.length == 1
          ? 'Falta ${formatMoney(total)}'
          : '${_joined(names)} · falta ${formatMoney(total)}',
    );
  }

  static const int hourOfDay = 9;

  /// The due day and the lead, so a bill due tomorrow and one due today never
  /// share an id at the same 9h. `yyyymmdd * 10 + days` stays below 2^31.
  static int idFor(DateTime due, int daysAhead) =>
      (due.year * 10000 + due.month * 100 + due.day) * 10 + daysAhead;

  final int id;
  final DateTime at;
  final String title;
  final String body;

  static List<DueReminder> plan(
    Iterable<Payable> payables, {
    required DateTime now,
    ReminderLead lead = ReminderLead.both,
  }) {
    final billsByDueDay = <DateTime, List<Payable>>{};
    for (final payable in payables) {
      if (payable.isPaid) continue;
      final due = payable.dueDate;
      billsByDueDay
          .putIfAbsent(DateTime(due.year, due.month, due.day), () => [])
          .add(payable);
    }

    final reminders = <DueReminder>[
      for (final entry in billsByDueDay.entries)
        for (final daysAhead in lead.daysAhead)
          DueReminder.forBills(entry.key, daysAhead, entry.value),
    ].where((reminder) => reminder.at.isAfter(now)).toList();

    return reminders..sort((a, b) {
      final byMoment = a.at.compareTo(b.at);
      return byMoment != 0 ? byMoment : a.id.compareTo(b.id);
    });
  }

  static String _joined(List<String> names) => names.length == 1
      ? names.single
      : '${names.sublist(0, names.length - 1).join(', ')} e ${names.last}';
}
