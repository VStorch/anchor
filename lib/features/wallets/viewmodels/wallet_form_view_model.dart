import 'package:flutter/foundation.dart';

import '../models/payout.dart';
import '../models/payout_schedule.dart';
import '../models/wallet.dart';
import '../models/wallet_kind.dart';
import '../repositories/wallet_repository.dart';

class WalletFormViewModel extends ChangeNotifier {
  WalletFormViewModel({
    required WalletRepository repository,
    Wallet? wallet,
    int suggestedColorIndex = 0,
  }) : _repository = repository,
       _wallet = wallet,
       _name = wallet?.name ?? '',
       _kind = wallet?.kind ?? WalletKind.salary,
       _colorIndex = wallet?.colorIndex ?? suggestedColorIndex,
       _payouts = List<Payout>.of(wallet?.payouts ?? const <Payout>[]);

  final WalletRepository _repository;
  final Wallet? _wallet;
  final List<int> _removedPayoutIds = <int>[];

  String _name;
  WalletKind _kind;
  int _colorIndex;
  List<Payout> _payouts;
  bool _isSaving = false;

  bool get isEditing => _wallet != null;

  String get name => _name;

  WalletKind get kind => _kind;

  int get colorIndex => _colorIndex;

  List<Payout> get payouts => List<Payout>.unmodifiable(_payouts);

  bool get isSaving => _isSaving;

  double get monthlyTotal =>
      _payouts.fold(0, (total, payout) => total + payout.amount);

  bool get isValid => _name.trim().isNotEmpty && _payouts.isNotEmpty;

  void setName(String value) {
    _name = value;
    notifyListeners();
  }

  void setKind(WalletKind value) {
    _kind = value;
    notifyListeners();
  }

  void setColorIndex(int value) {
    _colorIndex = value;
    notifyListeners();
  }

  void addPayout({
    required String label,
    required double amount,
    required int day,
    required PayoutSchedule schedule,
  }) => _replacePayouts(<Payout>[
    ..._payouts,
    _draft(label: label, amount: amount, day: day, schedule: schedule),
  ]);

  void updatePayoutAt(
    int index, {
    required String label,
    required double amount,
    required int day,
    required PayoutSchedule schedule,
  }) => _replacePayouts(
    <Payout>[..._payouts]
      ..[index] = _draft(
        existing: _payouts[index],
        label: label,
        amount: amount,
        day: day,
        schedule: schedule,
      ),
  );

  Payout _draft({
    Payout? existing,
    required String label,
    required double amount,
    required int day,
    required PayoutSchedule schedule,
  }) => Payout(
    id: existing?.id,
    walletId: _wallet?.id ?? 0,
    label: label.trim(),
    amount: amount,
    day: day,
    schedule: schedule,
    createdAt: existing?.createdAt ?? DateTime.now(),
  );

  void _replacePayouts(List<Payout> payouts) {
    _payouts = payouts..sort((a, b) => a.day.compareTo(b.day));
    notifyListeners();
  }

  void removePayoutAt(int index) {
    final removed = _payouts[index];
    if (removed.id != null) _removedPayoutIds.add(removed.id!);
    _payouts = <Payout>[..._payouts]..removeAt(index);
    notifyListeners();
  }

  Future<void> save() async {
    if (!isValid || _isSaving) return;
    _isSaving = true;
    notifyListeners();

    await _repository.saveWalletWithPayouts(
      Wallet(
        id: _wallet?.id,
        name: _name.trim(),
        kind: _kind,
        colorIndex: _colorIndex,
        createdAt: _wallet?.createdAt ?? DateTime.now(),
      ),
      payouts: _payouts,
      removedPayoutIds: _removedPayoutIds,
    );

    _isSaving = false;
    notifyListeners();
  }
}
