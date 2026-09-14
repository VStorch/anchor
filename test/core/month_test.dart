import 'package:anchor/core/utils/holidays.dart';
import 'package:anchor/core/utils/month.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Month', () {
    test('converte de e para chave', () {
      expect(Month.fromKey('2026-03'), const Month(2026, 3));
      expect(const Month(2026, 3).key, '2026-03');
    });

    test('sugere uma data dentro do mês que está na tela', () {
      final today = DateTime.now();
      final past = Month.current().addMonths(-7);

      expect(Month.fromDate(past.suggestedDate), past);
      expect(Month.current().suggestedDate.day, today.day);
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

    test('encontra o quinto dia útil pulando o fim de semana e o feriado', () {
      expect(const Month(2026, 9).businessDay(5), DateTime(2026, 9, 8));
      expect(const Month(2026, 11).businessDay(5), DateTime(2026, 11, 9));
    });

    test('pula o feriado que cai no primeiro dia útil', () {
      expect(const Month(2026, 11).businessDay(1), DateTime(2026, 11, 3));
    });

    test('ignora o fim de semana no começo do mês', () {
      expect(const Month(2026, 8).businessDay(1), DateTime(2026, 8, 3));
      expect(const Month(2026, 8).businessDay(5), DateTime(2026, 8, 7));
    });

    test('para no último dia útil quando o mês não tem tantos', () {
      expect(const Month(2026, 8).businessDay(30), DateTime(2026, 8, 31));
    });
  });

  group('BrazilianHolidays', () {
    test('calcula a Páscoa', () {
      expect(BrazilianHolidays.easter(2026), DateTime(2026, 4, 5));
      expect(BrazilianHolidays.easter(2027), DateTime(2027, 3, 28));
    });

    test('reconhece os feriados móveis', () {
      expect(BrazilianHolidays.isHoliday(DateTime(2026, 2, 16)), isTrue);
      expect(BrazilianHolidays.isHoliday(DateTime(2026, 2, 17)), isTrue);
      expect(BrazilianHolidays.isHoliday(DateTime(2026, 4, 3)), isTrue);
      expect(BrazilianHolidays.isHoliday(DateTime(2026, 6, 4)), isTrue);
      expect(BrazilianHolidays.isHoliday(DateTime(2026, 2, 18)), isFalse);
    });

    test('reconhece os feriados fixos', () {
      expect(BrazilianHolidays.isHoliday(DateTime(2026, 9, 7)), isTrue);
      expect(BrazilianHolidays.isHoliday(DateTime(2027, 11, 20)), isTrue);
      expect(BrazilianHolidays.isHoliday(DateTime(2026, 9, 8)), isFalse);
    });
  });
}
