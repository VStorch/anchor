import '../../../core/utils/month.dart';
import 'payout_schedule.dart';

class Payout {
  const Payout({
    this.id,
    required this.walletId,
    required this.label,
    required this.amount,
    required this.day,
    this.schedule = PayoutSchedule.dayOfMonth,
    required this.createdAt,
  });

  factory Payout.fromMap(Map<String, Object?> map) => Payout(
    id: map['id'] as int?,
    walletId: map['wallet_id'] as int,
    label: map['label'] as String,
    amount: (map['amount'] as num).toDouble(),
    day: map['day_of_month'] as int,
    schedule: PayoutSchedule.fromId(map['schedule_kind'] as String),
    createdAt:
        DateTime.tryParse(map['created_at'] as String? ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0),
  );

  static const int maxBusinessDay = 22;

  final int? id;
  final int walletId;
  final String label;
  final double amount;
  final int day;
  final PayoutSchedule schedule;
  final DateTime createdAt;

  Month get startMonth => Month.fromDate(createdAt);

  DateTime dateIn(Month month) => switch (schedule) {
    PayoutSchedule.dayOfMonth => month.dayOf(day),
    PayoutSchedule.businessDay => month.businessDay(day),
    PayoutSchedule.businessDaySaturday => month.businessDay(
      day,
      countSaturday: true,
    ),
  };

  /// This month's date while it has not gone by, else next month's.
  DateTime nextDate(DateTime today) {
    final month = Month.fromDate(today);
    final thisMonth = dateIn(month);
    final startOfToday = DateTime(today.year, today.month, today.day);
    return thisMonth.isBefore(startOfToday) ? dateIn(month.next) : thisMonth;
  }

  /// The name the user gave this payout, or how it is scheduled when the
  /// wallet has more than one and none was named.
  String get nameOrSchedule => label.trim().isEmpty ? scheduleLabel : label;

  String get scheduleLabel => switch (schedule) {
    PayoutSchedule.dayOfMonth => 'dia $day',
    PayoutSchedule.businessDay => '$dayº dia útil',
    PayoutSchedule.businessDaySaturday => '$dayº dia útil (conta sábado)',
  };

  Map<String, Object?> toMap() => <String, Object?>{
    if (id != null) 'id': id,
    'wallet_id': walletId,
    'label': label,
    'amount': amount,
    'day_of_month': day,
    'schedule_kind': schedule.id,
    'created_at': createdAt.toIso8601String(),
  };

  Payout copyWith({
    int? id,
    int? walletId,
    String? label,
    double? amount,
    int? day,
    PayoutSchedule? schedule,
    DateTime? createdAt,
  }) => Payout(
    id: id ?? this.id,
    walletId: walletId ?? this.walletId,
    label: label ?? this.label,
    amount: amount ?? this.amount,
    day: day ?? this.day,
    schedule: schedule ?? this.schedule,
    createdAt: createdAt ?? this.createdAt,
  );
}
