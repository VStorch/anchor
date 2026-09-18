import 'package:anchor/core/utils/month.dart';
import 'package:anchor/features/budget/models/wallet_summary.dart';
import 'package:anchor/features/wallets/models/outflow.dart';
import 'package:anchor/features/wallets/models/receipt.dart';
import 'package:anchor/features/wallets/models/wallet.dart';
import 'package:anchor/features/wallets/models/wallet_kind.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final today = DateTime(2026, 9, 16, 10);
  final voucher = Wallet(
    id: 2,
    name: 'VR',
    kind: WalletKind.benefit,
    colorIndex: 1,
    createdAt: DateTime(2026, 3),
  );

  WalletSummary summaryOf(
    Month month, {
    required List<Receipt> receipts,
    required List<Outflow> outflows,
  }) => WalletSummary.buildAll(
    month: month,
    wallets: [voucher],
    receipts: receipts,
    payments: const [],
    occurrences: const [],
    checks: const [],
    outflows: outflows,
    today: today,
  ).single;

  group('barra do benefício', () {
    final receipts = [
      for (var month = 3; month <= 9; month++)
        Receipt(
          walletId: 2,
          month: Month(2026, month),
          amount: 600,
          receivedAt: DateTime(2026, month, 1),
        ),
    ];
    final outflows = [
      for (var month = 3; month <= 8; month++)
        Outflow(
          walletId: 2,
          description: 'Mercado',
          amount: 590,
          spentAt: DateTime(2026, month, 20),
        ),
      Outflow(
        walletId: 2,
        description: 'Padaria',
        amount: 30,
        spentAt: DateTime(2026, 9, 10),
      ),
    ];

    test('sem saldo informado não esvazia com os meses que passaram', () {
      final summary = summaryOf(
        const Month(2026, 9),
        receipts: receipts,
        outflows: outflows,
      );

      expect(summary.balance, 630);
      expect(summary.spentInCurrentMonth, 30);
      expect(summary.leftRatio, closeTo(630 / 660, 0.0001));
    });

    test('fala do mês de hoje, qualquer que seja o mês na tela', () {
      final summary = summaryOf(
        const Month(2026, 5),
        receipts: receipts,
        outflows: outflows,
      );

      expect(summary.currentMonth, const Month(2026, 9));
      expect(summary.spentInCurrentMonth, 30);
      expect(summary.leftRatio, closeTo(630 / 660, 0.0001));
    });

    test('sem saldo a barra fica vazia', () {
      final summary = summaryOf(
        const Month(2026, 9),
        receipts: const [],
        outflows: [outflows.last],
      );

      expect(summary.balance, -30);
      expect(summary.leftRatio, 0);
    });
  });
}
