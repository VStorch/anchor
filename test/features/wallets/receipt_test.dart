import 'package:anchor/core/utils/month.dart';
import 'package:anchor/features/wallets/models/receipt.dart';
import 'package:anchor/features/wallets/models/receipt_kind.dart';
import 'package:anchor/features/wallets/models/receipt_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('editar um ajuste de saldo continua sendo ajuste', () {
    final adjustment = Receipt(
      id: 4,
      walletId: 1,
      month: const Month(2026, 9),
      amount: 250,
      receivedAt: DateTime(2026, 9, 2),
      kind: ReceiptKind.adjustment,
    );

    final edited = adjustment.copyWith(
      amount: 300,
      receivedAt: DateTime(2026, 9, 3),
      status: ReceiptStatus.confirmed,
    );

    expect(edited.kind, ReceiptKind.adjustment);
    expect(edited.isAdjustment, isTrue);
    expect(edited.amount, 300);
  });
}
