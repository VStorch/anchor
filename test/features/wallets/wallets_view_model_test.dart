import 'package:anchor/features/wallets/viewmodels/wallets_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 9, 13, 18, 30);

  test('o saldo informado para hoje vale a partir de agora', () {
    expect(WalletsViewModel.checkedAtFor(DateTime(2026, 9, 13), now: now), now);
  });

  test('o saldo informado para um dia passado fecha aquele dia', () {
    expect(
      WalletsViewModel.checkedAtFor(DateTime(2026, 9, 10), now: now),
      DateTime(2026, 9, 10, 23, 59, 59, 999),
    );
  });
}
