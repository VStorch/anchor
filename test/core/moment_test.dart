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

  group('movimento no dia do saldo informado', () {
    final checkedAt = DateTime(2026, 9, 13, 13);

    test('pergunta o lado só no mesmo dia do saldo', () {
      expect(needsCheckSide(DateTime(2026, 9, 13, 9), checkedAt), isTrue);
      expect(needsCheckSide(DateTime(2026, 9, 12), checkedAt), isFalse);
      expect(needsCheckSide(DateTime(2026, 9, 13), null), isFalse);
    });

    test('não pergunta quando o saldo fecha o dia', () {
      expect(
        needsCheckSide(DateTime(2026, 9, 10), endOfDay(DateTime(2026, 9, 10))),
        isFalse,
      );
    });

    test('antes fica um segundo antes do saldo', () {
      expect(
        stampAround(
          DateTime(2026, 9, 13),
          checkedAt: checkedAt,
          side: CheckSide.before,
          now: now,
        ),
        DateTime(2026, 9, 13, 12, 59, 59),
      );
    });

    test('depois fica um segundo depois do saldo', () {
      expect(
        stampAround(DateTime(2026, 9, 13), checkedAt: checkedAt, now: now),
        DateTime(2026, 9, 13, 13, 0, 1),
      );
    });

    test('em outro dia vale o carimbo de sempre', () {
      expect(
        stampAround(
          DateTime(2026, 9, 12),
          checkedAt: checkedAt,
          side: CheckSide.before,
          now: now,
        ),
        DateTime(2026, 9, 12, 12),
      );
      expect(
        stampAround(DateTime(2026, 9, 13), checkedAt: null, now: now),
        now,
      );
    });

    test('o lado de um instante já gravado', () {
      expect(sideOf(DateTime(2026, 9, 13, 19), checkedAt), CheckSide.after);
      expect(sideOf(DateTime(2026, 9, 13, 12), checkedAt), CheckSide.before);
    });
  });
}
