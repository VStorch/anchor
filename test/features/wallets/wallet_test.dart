import 'package:anchor/core/utils/month.dart';
import 'package:anchor/features/wallets/models/payout.dart';
import 'package:anchor/features/wallets/models/payout_schedule.dart';
import 'package:anchor/features/wallets/models/receipt.dart';
import 'package:anchor/features/wallets/models/wallet.dart';
import 'package:anchor/features/wallets/models/wallet_kind.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const september = Month(2026, 9);

  Payout payout({
    required int id,
    String label = '',
    int day = 5,
    PayoutSchedule schedule = PayoutSchedule.businessDay,
  }) => Payout(
    id: id,
    walletId: 1,
    label: label,
    amount: 3200,
    day: day,
    schedule: schedule,
    createdAt: DateTime(2026),
  );

  Wallet salary(List<Payout> payouts) => Wallet(
    id: 1,
    name: 'Salário',
    kind: WalletKind.salary,
    colorIndex: 0,
    createdAt: DateTime(2026),
    payouts: payouts,
  );

  Receipt receipt({int? payoutId}) => Receipt(
    id: 10,
    walletId: 1,
    payoutId: payoutId,
    month: september,
    amount: 3200,
    receivedAt: DateTime(2026, 9, 8),
  );

  test('com um recebimento só, o título é o nome da carteira', () {
    final wallet = salary([payout(id: 1, label: 'Mensal')]);
    final entry = receipt(payoutId: 1);

    expect(wallet.titleFor(entry), 'Salário');
    expect(wallet.titleIsWalletName(entry), isTrue);
  });

  test('com dois recebimentos, o título leva o nome do recebimento', () {
    final wallet = salary([
      payout(id: 1),
      payout(id: 2, label: 'Adiantamento', day: 20),
    ]);
    final entry = receipt(payoutId: 2);

    expect(wallet.titleFor(entry), 'Salário · Adiantamento');
    expect(wallet.titleIsWalletName(entry), isFalse);
  });

  test('sem nome, o recebimento é dito pelo dia em que cai', () {
    final wallet = salary([
      payout(id: 1),
      payout(id: 2, day: 20, schedule: PayoutSchedule.dayOfMonth),
    ]);

    expect(wallet.titleFor(receipt(payoutId: 2)), 'Salário · dia 20');
    expect(wallet.titleFor(receipt(payoutId: 1)), 'Salário · 5º dia útil');
  });

  test('entrada sem recebimento no calendário é entrada extra', () {
    final wallet = salary([payout(id: 1)]);
    final entry = receipt();

    expect(wallet.titleFor(entry), 'Entrada extra');
    expect(wallet.titleIsWalletName(entry), isFalse);
    expect(wallet.titleFor(receipt(payoutId: 9)), 'Entrada extra');
  });
}
