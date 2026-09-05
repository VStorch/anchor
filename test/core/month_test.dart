import 'package:anchor/core/utils/month.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Month', () {
    test('converte de e para chave', () {
      expect(Month.fromKey('2026-03'), const Month(2026, 3));
      expect(const Month(2026, 3).key, '2026-03');
    });

    test('avança e volta atravessando o ano', () {
      expect(const Month(2026, 12).next, const Month(2027, 1));
      expect(const Month(2026, 1).previous, const Month(2025, 12));
      expect(const Month(2026, 8).addMonths(6), const Month(2027, 2));
    });

    test('conta a distância em meses', () {
      expect(const Month(2027, 2).monthsSince(const Month(2026, 8)), 6);
      expect(const Month(2026, 8).monthsSince(const Month(2027, 2)), -6);
    });

    test('compara na ordem cronológica', () {
      expect(const Month(2026, 1) < const Month(2026, 2), isTrue);
      expect(const Month(2027, 1) > const Month(2026, 12), isTrue);
      expect(const Month(2026, 5) >= const Month(2026, 5), isTrue);
    });

    test('limita o dia ao último dia do mês', () {
      expect(const Month(2026, 2).dayOf(31), DateTime(2026, 2, 28));
      expect(const Month(2026, 1).dayOf(15), DateTime(2026, 1, 15));
    });

    test('encontra o quinto dia útil pulando o fim de semana', () {
      expect(const Month(2026, 9).businessDay(5), DateTime(2026, 9, 7));
      expect(const Month(2026, 11).businessDay(5), DateTime(2026, 11, 6));
    });

    test('ignora o fim de semana no começo do mês', () {
      expect(const Month(2026, 8).businessDay(1), DateTime(2026, 8, 3));
      expect(const Month(2026, 8).businessDay(5), DateTime(2026, 8, 7));
    });

    test('para no último dia útil quando o mês não tem tantos', () {
      expect(const Month(2026, 8).businessDay(30), DateTime(2026, 8, 31));
    });
  });
}
