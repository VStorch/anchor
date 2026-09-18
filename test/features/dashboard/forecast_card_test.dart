import 'package:anchor/app/theme/app_theme.dart';
import 'package:anchor/core/utils/money.dart';
import 'package:anchor/core/utils/month.dart';
import 'package:anchor/features/budget/models/month_forecast.dart';
import 'package:anchor/features/dashboard/views/widgets/forecast_card.dart';
import 'package:anchor/features/wallets/models/wallet.dart';
import 'package:anchor/features/wallets/models/wallet_kind.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  const september = Month(2026, 9);

  setUpAll(() => initializeDateFormatting('pt_BR'));

  /// A salary with a R$ 600 reserve; the share is the smaller of what is
  /// left of it this month and the days-ahead pace, as the model builds it.
  MonthForecast forecastWith({
    required double left,
    required double pace,
    int daysLeft = 13,
    double spentToday = 0,
  }) {
    final smaller = left < pace ? left : pace;
    final share = smaller > 0 ? smaller : 0.0;
    return MonthForecast(
      month: september,
      daysLeft: daysLeft,
      daysLeftInCurrentMonth: daysLeft,
      daysInCurrentMonth: 30,
      unassignedToPay: 0,
      wallets: [
        WalletForecast(
          wallet: Wallet(
            id: 1,
            name: 'Salário',
            kind: WalletKind.salary,
            colorIndex: 0,
            createdAt: DateTime(2026, 9),
            monthlyReserve: 600,
          ),
          startBalance: 900,
          toReceive: 0,
          toPay: 200,
          reserveShares: [ReserveShare(month: september, amount: share)],
          spentToday: spentToday,
          reserveLeft: left,
          reservePace: pace,
        ),
      ],
    );
  }

  Future<void> pump(WidgetTester tester, MonthForecast forecast) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SingleChildScrollView(child: ForecastCard(forecast: forecast)),
        ),
      ),
    );
    await tester.tap(find.text('Como chegamos nisso'));
    await tester.pumpAndSettle();
  }

  testWidgets('com a reserva do mês gasta, o dia diz que ela acabou', (
    tester,
  ) async {
    final forecast = forecastWith(left: 0, pace: 260);
    expect(forecast.freeMoney.reserveState, ReserveState.usedUp);
    expect(forecast.freeMoney.dailyAllowance, 0);

    await pump(tester, forecast);

    expect(
      find.text('Por dia até 30/09: Reserva de setembro já usada'),
      findsOneWidget,
    );
    expect(
      find.text('Reserva do dia a dia · o que resta da reserva'),
      findsOneWidget,
    );
  });

  testWidgets('passar do ritmo hoje não diz que a reserva acabou', (
    tester,
  ) async {
    final forecast = forecastWith(left: 400, pace: -5, spentToday: 25);
    expect(forecast.freeMoney.reserveState, ReserveState.paceExceeded);

    await pump(tester, forecast);

    expect(
      find.text(
        'Por dia até 30/09: Hoje passou do ritmo da reserva '
        '(hoje já saiu ${formatMoney(25)})',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('já usada'), findsNothing);
  });

  testWidgets('limitada pelos dias, a reserva diz quantos dias faltam', (
    tester,
  ) async {
    final forecast = forecastWith(left: 500, pace: 260);
    expect(forecast.freeMoney.reserveState, ReserveState.byDaysLeft);

    await pump(tester, forecast);

    expect(
      find.text('Por dia até 30/09: ${formatMoney(20)} do salário'),
      findsOneWidget,
    );
    expect(find.text('Reserva do dia a dia · 13 dias de 30'), findsOneWidget);
  });

  testWidgets('limitada pelo que sobrou, a reserva não fala em dias', (
    tester,
  ) async {
    final forecast = forecastWith(left: 100, pace: 260);
    expect(forecast.freeMoney.reserveState, ReserveState.byWhatIsLeft);

    await pump(tester, forecast);

    expect(
      find.text('Reserva do dia a dia · o que resta da reserva'),
      findsOneWidget,
    );
  });

  testWidgets('no último dia fala em 1 dia, no singular', (tester) async {
    await pump(tester, forecastWith(left: 500, pace: 20, daysLeft: 1));

    expect(find.text('Reserva do dia a dia · 1 dia de 30'), findsOneWidget);
  });
}
