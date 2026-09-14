import 'package:anchor/core/utils/month.dart';
import 'package:anchor/features/wallets/models/receipt.dart';
import 'package:anchor/features/wallets/models/receipt_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('confirmar um recebimento do calendário mantém o mês dele', () {
    final predicted = Receipt(
      id: 4,
      walletId: 1,
      payoutId: 2,
      month: const Month(2026, 9),
      amount: 3200,
      receivedAt: DateTime(2026, 9, 8),
      status: ReceiptStatus.predicted,
    );

    final confirmed = predicted.copyWith(
      amount: 3150,
      receivedAt: DateTime(2026, 10, 1),
      status: ReceiptStatus.confirmed,
    );

    expect(confirmed.isConfirmed, isTrue);
    expect(confirmed.month, const Month(2026, 9));
    expect(confirmed.toMap().containsKey('kind'), isFalse);
  });
}
