import 'package:anchor/core/utils/month.dart';
import 'package:anchor/features/wallets/models/payout.dart';
import 'package:anchor/features/wallets/models/payout_schedule.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Payout salary(PayoutSchedule schedule) => Payout(
    walletId: 1,
    label: 'Salário',
    amount: 3000,
    day: 5,
    schedule: schedule,
    createdAt: DateTime(2026, 1, 1),
  );

  test('o dia útil que conta sábado cai na sexta antes do sábado', () {
    final payout = salary(PayoutSchedule.businessDaySaturday);

    expect(payout.dateIn(const Month(2026, 9)), DateTime(2026, 9, 4));
    expect(payout.scheduleLabel, '5º dia útil (conta sábado)');
  });

  test('o dia útil comum conta só de segunda a sexta', () {
    final payout = salary(PayoutSchedule.businessDay);

    expect(payout.dateIn(const Month(2026, 9)), DateTime(2026, 9, 8));
    expect(payout.scheduleLabel, '5º dia útil');
  });

  test('lê e grava o agendamento que conta sábado', () {
    final payout = salary(PayoutSchedule.businessDaySaturday);

    expect(
      Payout.fromMap({...payout.toMap(), 'id': 1}).schedule,
      PayoutSchedule.businessDaySaturday,
    );
    expect(payout.schedule.isBusinessDay, isTrue);
    expect(PayoutSchedule.dayOfMonth.isBusinessDay, isFalse);
  });

  test('a próxima data é a deste mês até ela passar', () {
    final payout = salary(PayoutSchedule.businessDay);

    expect(payout.nextDate(DateTime(2026, 9, 8, 18)), DateTime(2026, 9, 8));
    expect(payout.nextDate(DateTime(2026, 9, 9)), DateTime(2026, 10, 7));
  });
}
