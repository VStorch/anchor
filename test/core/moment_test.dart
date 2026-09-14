import 'package:anchor/core/utils/moment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 9, 13, 18, 30);

  test('um movimento de hoje fica com a hora de agora', () {
    expect(stampFor(DateTime(2026, 9, 13), now: now), now);
  });

  test('um movimento de outro dia fica ao meio-dia', () {
    expect(
      stampFor(DateTime(2026, 9, 10), now: now),
      DateTime(2026, 9, 10, 12),
    );
  });

  test('o fim do dia fica depois de qualquer movimento desse dia', () {
    final day = DateTime(2026, 9, 10, 8);

    expect(endOfDay(day), DateTime(2026, 9, 10, 23, 59, 59, 999));
    expect(endOfDay(day).isAfter(stampFor(day, now: now)), isTrue);
  });
}
