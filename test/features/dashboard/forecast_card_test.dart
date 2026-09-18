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

  MonthForecast forecastWith({required double reserveLeft}) => MonthForecast(
    month: september,
    daysLeft: 13,
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
        reserveShares: [ReserveShare(month: september, amount: reserveLeft)],
      ),
    ],
  );

  Future<void> pump(WidgetTester tester, MonthForecast forecast) =>
      tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(body: ForecastCard(forecast: forecast)),
        ),
      );

  testWidgets('com a reserva do mês gasta, o dia diz que ela acabou', (
    tester,
  ) async {
    final forecast = forecastWith(reserveLeft: 0);
    expect(forecast.freeMoney.reserveUsedUp, isTrue);
    expect(forecast.freeMoney.dailyAllowance, 0);

    await pump(tester, forecast);

    expect(
      find.text('Por dia até 30/09: Reserva de setembro já usada'),
      findsOneWidget,
    );
    expect(find.textContaining('${formatMoney(0)} do salário'), findsNothing);
  });

  testWidgets('com reserva sobrando, o dia mostra o valor', (tester) async {
    final forecast = forecastWith(reserveLeft: 260);
    expect(forecast.freeMoney.reserveUsedUp, isFalse);

    await pump(tester, forecast);

    expect(
      find.text('Por dia até 30/09: ${formatMoney(20)} do salário'),
      findsOneWidget,
    );
  });
}
