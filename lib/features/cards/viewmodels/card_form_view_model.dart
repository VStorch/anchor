import 'package:flutter/foundation.dart';

import '../models/credit_card.dart';
import '../repositories/card_repository.dart';

class CardFormViewModel extends ChangeNotifier {
  CardFormViewModel({
    required CardRepository repository,
    CreditCard? card,
    int? likelyWalletId,
  }) : _repository = repository,
       _card = card,
       _name = card?.name ?? '',
       _closingDay = card?.closingDay ?? 3,
       _dueDay = card?.dueDay ?? 10,
       _walletId = card == null ? likelyWalletId : card.walletId;

  final CardRepository _repository;
  final CreditCard? _card;

  String _name;
  int _closingDay;
  int _dueDay;
  int? _walletId;
  bool _isSaving = false;

  bool get isEditing => _card != null;
  String get name => _name;
  int get closingDay => _closingDay;
  int get dueDay => _dueDay;
  int? get walletId => _walletId;
  bool get isSaving => _isSaving;
  bool get isValid => _name.trim().isNotEmpty;

  void setName(String value) {
    _name = value;
    notifyListeners();
  }

  void setClosingDay(int value) {
    _closingDay = value;
    notifyListeners();
  }

  void setDueDay(int value) {
    _dueDay = value;
    notifyListeners();
  }

  void setWalletId(int? value) {
    _walletId = value;
    notifyListeners();
  }

  Future<void> save() async {
    if (!isValid || _isSaving) return;
    _isSaving = true;
    notifyListeners();

    await _repository.saveCard(
      CreditCard(
        id: _card?.id,
        name: _name.trim(),
        closingDay: _closingDay,
        dueDay: _dueDay,
        walletId: _walletId,
        createdAt: _card?.createdAt ?? DateTime.now(),
      ),
    );

    _isSaving = false;
    notifyListeners();
  }

  Future<void> delete() async {
    final id = _card?.id;
    if (id != null) await _repository.deleteCard(id);
  }
}
