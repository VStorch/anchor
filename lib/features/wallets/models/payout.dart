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
  });

  factory Payout.fromMap(Map<String, Object?> map) => Payout(
    id: map['id'] as int?,
    walletId: map['wallet_id'] as int,
    label: map['label'] as String,
    amount: (map['amount'] as num).toDouble(),
    day: map['day_of_month'] as int,
    schedule: PayoutSchedule.fromId(map['schedule_kind'] as String),
  );

  static const int maxBusinessDay = 22;

  final int? id;
  final int walletId;
  final String label;
  final double amount;
  final int day;
  final PayoutSchedule schedule;

  DateTime dateIn(Month month) => switch (schedule) {
    PayoutSchedule.dayOfMonth => month.dayOf(day),
    PayoutSchedule.businessDay => month.businessDay(day),
  };

  String get scheduleLabel => switch (schedule) {
    PayoutSchedule.dayOfMonth => 'dia $day',
    PayoutSchedule.businessDay => '$dayº dia útil',
  };

  Map<String, Object?> toMap() => <String, Object?>{
    if (id != null) 'id': id,
    'wallet_id': walletId,
    'label': label,
    'amount': amount,
    'day_of_month': day,
    'schedule_kind': schedule.id,
  };

  Payout copyWith({
    int? id,
    int? walletId,
    String? label,
    double? amount,
    int? day,
    PayoutSchedule? schedule,
  }) => Payout(
    id: id ?? this.id,
    walletId: walletId ?? this.walletId,
    label: label ?? this.label,
    amount: amount ?? this.amount,
    day: day ?? this.day,
    schedule: schedule ?? this.schedule,
  );
}
