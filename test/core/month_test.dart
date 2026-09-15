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

    test('num mês futuro sugere hoje, nunca uma data que não chegou', () {
      final suggested = Month.current().addMonths(3).suggestedDate;

      expect(Month.fromDate(suggested), Month.current());
      expect(suggested.isAfter(DateTime.now()), isFalse);
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

    test('trata a posição zero ou negativa como o primeiro dia útil', () {
      const september = Month(2026, 9);
      expect(september.businessDay(0), september.businessDay(1));
      expect(september.businessDay(-3), DateTime(2026, 9, 1));
    });

    test('contando sábado, o 5º dia útil que cai no sábado recua para a '
        'sexta', () {
      const september = Month(2026, 9);
      expect(
        september.businessDay(5, countSaturday: true),
        DateTime(2026, 9, 4),
      );
      expect(september.businessDay(5), DateTime(2026, 9, 8));
    });

    test('contando sábado, pula domingo e feriado', () {
      // Out/2026: 1 qui, 2 sex, 3 sáb, 5 seg, 6 ter; 12 é feriado.
      expect(
        const Month(2026, 10).businessDay(5, countSaturday: true),
        DateTime(2026, 10, 6),
      );
      // Ago/2026 começa num sábado: o 1º dia conta, mas o pagamento vai para
      // o próximo dia útil, já que não há nenhum antes dele no mês.
      expect(
        const Month(2026, 8).businessDay(1, countSaturday: true),
        DateTime(2026, 8, 3),
      );
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

    test('20 de novembro só é feriado nacional a partir de 2024', () {
      expect(BrazilianHolidays.isHoliday(DateTime(2023, 11, 20)), isFalse);
      expect(BrazilianHolidays.isHoliday(DateTime(2024, 11, 20)), isTrue);
    });

    test('a Páscoa bate com os anos conhecidos', () {
      final known = <int, DateTime>{
        1900: DateTime(1900, 4, 15),
        2000: DateTime(2000, 4, 23),
        2008: DateTime(2008, 3, 23),
        2011: DateTime(2011, 4, 24),
        2038: DateTime(2038, 4, 25),
        2100: DateTime(2100, 3, 28),
      };
      known.forEach((year, date) {
        expect(BrazilianHolidays.easter(year), date, reason: '$year');
      });
    });
  });
}
