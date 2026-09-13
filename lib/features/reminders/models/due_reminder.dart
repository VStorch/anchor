import '../../../core/utils/money.dart';
import '../../expenses/models/expense_occurrence.dart';

class DueReminder {
  const DueReminder({
    required this.id,
    required this.at,
    required this.title,
    required this.body,
  });

  factory DueReminder.forDay(DateTime at, List<ExpenseOccurrence> bills) {
    final total = bills.fold<double>(0, (sum, bill) => sum + bill.remaining);
    final names = bills.map((bill) => bill.expense.name).toList();

    return DueReminder(
      id: at.year * 10000 + at.month * 100 + at.day,
      at: at,
      title: bills.length == 1
          ? '${names.single} vence hoje'
          : '${bills.length} contas vencem hoje',
      body: bills.length == 1
          ? 'Falta ${formatMoney(total)}'
          : '${_joined(names)} · falta ${formatMoney(total)}',
    );
  }

  static const int hourOfDay = 9;

  final int id;
  final DateTime at;
  final String title;
  final String body;

  static List<DueReminder> plan(
    Iterable<ExpenseOccurrence> occurrences, {
    required DateTime now,
  }) {
    final billsByMoment = <DateTime, List<ExpenseOccurrence>>{};
    for (final occurrence in occurrences) {
      if (occurrence.isPaid) continue;

      final due = occurrence.dueDate;
      final at = DateTime(due.year, due.month, due.day, hourOfDay);
      if (!at.isAfter(now)) continue;

      billsByMoment
          .putIfAbsent(at, () => <ExpenseOccurrence>[])
          .add(occurrence);
    }

    final moments = billsByMoment.keys.toList()..sort();
    return [
      for (final at in moments) DueReminder.forDay(at, billsByMoment[at]!),
    ];
  }

  static String _joined(List<String> names) => names.length == 1
      ? names.single
      : '${names.sublist(0, names.length - 1).join(', ')} e ${names.last}';
}
