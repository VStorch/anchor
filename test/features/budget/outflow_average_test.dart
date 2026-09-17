import 'package:anchor/core/utils/month.dart';
import 'package:anchor/features/budget/models/outflow_average.dart';
import 'package:anchor/features/wallets/models/outflow.dart';
import 'package:anchor/features/wallets/models/wallet.dart';
import 'package:anchor/features/wallets/models/wallet_kind.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final today = DateTime(2026, 9, 15);
  final salary = Wallet(
    id: 1,
    name: 'Salário',
    kind: WalletKind.salary,
    colorIndex: 0,
    createdAt: DateTime(2026, 5, 20),
  );

  Outflow spent(int month, double amount, {int walletId = 1}) => Outflow(
    walletId: walletId,
    description: 'Mercado',
    amount: amount,
    spentAt: DateTime(2026, month, 10),
  );

  OutflowAverage? averageOf(List<Outflow> outflows) =>
      OutflowAverage.of(wallet: salary, outflows: outflows, today: today);

  test('sem gastos lançados não há média para sugerir', () {
    expect(averageOf(const []), isNull);
    expect(averageOf([spent(9, 80)]), isNull);
  });

  test('o mês em que a carteira foi criada fica de fora', () {
    expect(averageOf([spent(5, 900)]), isNull);
    expect(averageOf([spent(5, 900), spent(6, 300)])!.amount, 300);
  });

  test('a média de dois meses completos', () {
    final average = averageOf([
      spent(7, 400),
      spent(7, 50),
      spent(8, 390),
      spent(8, 100, walletId: 2),
    ])!;

    expect(average.amount, 420);
    expect(
      (average.from, average.to),
      (const Month(2026, 7), const Month(2026, 8)),
    );
  });

  test('um mês sem gasto lançado não puxa a média para baixo', () {
    final average = averageOf([spent(6, 300), spent(8, 500)])!;

    expect(average.amount, 400);
    expect(average.from, const Month(2026, 6));
  });

  test('conta só os três últimos meses com gasto', () {
    final older = Wallet(
      id: 1,
      name: 'Salário',
      kind: WalletKind.salary,
      colorIndex: 0,
      createdAt: DateTime(2026),
    );

    final average = OutflowAverage.of(
      wallet: older,
      outflows: [spent(3, 1000), spent(6, 300), spent(7, 300), spent(8, 600)],
      today: today,
    )!;

    expect(average.amount, 400);
    expect(average.from, const Month(2026, 6));
  });
}
