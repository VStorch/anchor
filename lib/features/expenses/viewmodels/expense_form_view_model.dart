import 'package:flutter/foundation.dart';

import '../../../core/utils/month.dart';
import '../models/expense.dart';
import '../models/expense_type.dart';
import '../repositories/expense_repository.dart';

class ExpenseFormViewModel extends ChangeNotifier {
  ExpenseFormViewModel({
    required ExpenseRepository repository,
    required Month referenceMonth,
    Expense? expense,
    int? likelyWalletId,
  }) : _repository = repository,
       _expense = expense,
       _name = expense?.name ?? '',
       _type = expense?.type ?? ExpenseType.recurring,
       _amount = expense?.amount ?? 0,
       _dueDay = expense?.dueDay ?? 5,
       _startMonth = expense?.startMonth ?? referenceMonth,
       _totalInstallments = expense?.totalInstallments ?? 12,
       _settledInstallments = expense?.settledInstallments ?? 0,
       _walletId = expense == null ? likelyWalletId : expense.walletId;

  final ExpenseRepository _repository;
  final Expense? _expense;

  String _name;
  ExpenseType _type;
  double _amount;
  int _dueDay;
  Month _startMonth;
  int _totalInstallments;
  int _settledInstallments;
  int? _walletId;
  bool _isSaving = false;

  bool get isEditing => _expense != null;

  String get name => _name;

  ExpenseType get type => _type;

  double get amount => _amount;

  int get dueDay => _dueDay;

  Month get startMonth => _startMonth;

  int get totalInstallments => _totalInstallments;

  int get settledInstallments => _settledInstallments;

  int? get walletId => _walletId;

  bool get isSaving => _isSaving;

  bool get isInstallment => _type == ExpenseType.installment;

  int get remainingInstallments => _totalInstallments - _settledInstallments;

  double get totalCommitted =>
      isInstallment ? _amount * remainingInstallments : _amount;

  Month get lastMonth => isInstallment
      ? _startMonth.addMonths(remainingInstallments - 1)
      : _startMonth;

  bool get isValid =>
      _name.trim().isNotEmpty &&
      _amount > 0 &&
      (!isInstallment || remainingInstallments > 0);

  String? get installmentPlan => isInstallment
      ? 'Faltam $remainingInstallments parcelas até ${lastMonth.label}'
      : null;

  void setName(String value) {
    _name = value;
    notifyListeners();
  }

  void setType(ExpenseType value) {
    if (_type == value) return;
    _type = value;
    if (value != ExpenseType.installment) {
      _settledInstallments = 0;
    }
    notifyListeners();
  }

  void setAmount(double value) {
    _amount = value;
    notifyListeners();
  }

  void setDueDay(int value) {
    _dueDay = value;
    notifyListeners();
  }

  void setStartMonth(Month value) {
    _startMonth = value;
    notifyListeners();
  }

  void setTotalInstallments(int value) {
    _totalInstallments = value.clamp(1, 480);
    if (_settledInstallments >= _totalInstallments) {
      _settledInstallments = _totalInstallments - 1;
    }
    notifyListeners();
  }

  void setSettledInstallments(int value) {
    _settledInstallments = value.clamp(0, _totalInstallments - 1);
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

    await _repository.saveExpense(
      Expense(
        id: _expense?.id,
        name: _name.trim(),
        type: _type,
        amount: _amount,
        dueDay: _dueDay,
        startMonth: _startMonth,
        endMonth: _type == ExpenseType.recurring ? _expense?.endMonth : null,
        totalInstallments: isInstallment ? _totalInstallments : null,
        settledInstallments: isInstallment ? _settledInstallments : 0,
        walletId: _walletId,
        createdAt: _expense?.createdAt ?? DateTime.now(),
      ),
    );

    _isSaving = false;
    notifyListeners();
  }
}
