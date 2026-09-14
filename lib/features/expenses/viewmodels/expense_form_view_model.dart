import 'package:flutter/foundation.dart';

import '../../../core/utils/month.dart';
import '../../cards/models/credit_card.dart';
import '../models/expense.dart';
import '../models/expense_payment.dart';
import '../models/expense_type.dart';
import '../repositories/expense_repository.dart';

typedef PaymentSource = ({int? walletId, int? cardId});

class ExpenseFormViewModel extends ChangeNotifier {
  ExpenseFormViewModel({
    required ExpenseRepository repository,
    required Month referenceMonth,
    Expense? expense,
    int? likelyWalletId,
    List<CreditCard> cards = const <CreditCard>[],
    CreditCard? card,
    List<ExpensePayment> payments = const <ExpensePayment>[],
    Month? invoiceMonth,
    DateTime? now,
  }) : _repository = repository,
       _now = now ?? DateTime.now(),
       _openedInvoiceMonth = invoiceMonth,
       _cards = cards,
       _expense = expense,
       _payments = payments,
       _name = expense?.name ?? '',
       _type =
           expense?.type ??
           (card == null ? ExpenseType.recurring : ExpenseType.single),
       _amount = expense?.amount ?? 0,
       _dueDay = expense?.dueDay ?? 5,
       _startMonth = expense?.startMonth ?? referenceMonth,
       _endMonth = expense?.type == ExpenseType.recurring
           ? expense?.endMonth
           : null,
       _totalInstallments = expense?.totalInstallments ?? 12,
       _settledInstallments = expense?.settledInstallments ?? 0,
       _walletId = expense == null ? likelyWalletId : expense.walletId,
       _cardId = expense?.cardId ?? card?.id {
    _purchasedAt = expense == null ? _dayOf(_now) : expense.purchasedAt;
  }

  final ExpenseRepository _repository;
  final Expense? _expense;
  final List<CreditCard> _cards;
  final List<ExpensePayment> _payments;
  final DateTime _now;
  final Month? _openedInvoiceMonth;

  String _name;
  ExpenseType _type;
  double _amount;
  int _dueDay;
  Month _startMonth;
  Month? _endMonth;
  int _totalInstallments;
  int _settledInstallments;
  int? _walletId;
  int? _cardId;
  DateTime? _purchasedAt;
  bool _isSaving = false;

  bool get isEditing => _expense != null;

  String get name => _name;

  ExpenseType get type => _type;

  double get amount => _amount;

  int get dueDay => _dueDay;

  /// A card purchase with a date starts on the invoice that date falls in,
  /// moved on by the parcels already paid.
  Month get startMonth {
    final invoiceMonth = this.invoiceMonth;
    if (invoiceMonth == null) return _startMonth;
    return invoiceMonth.addMonths(isInstallment ? _settledInstallments : 0);
  }

  DateTime? get purchasedAt => _purchasedAt;

  Month? get invoiceMonth {
    final card = this.card;
    final purchasedAt = _purchasedAt;
    if (card == null || purchasedAt == null) return null;
    return card.invoiceMonthFor(purchasedAt);
  }

  /// "Adicionar compra" opened from one invoice, but the purchase day belongs
  /// to another.
  bool get leavesOpenedInvoice =>
      _openedInvoiceMonth != null &&
      invoiceMonth != null &&
      invoiceMonth != _openedInvoiceMonth;

  Month? get endMonth => _endMonth;

  bool get endsBeforeStart =>
      _type == ExpenseType.recurring &&
      _endMonth != null &&
      _endMonth! < startMonth;

  int get totalInstallments => _totalInstallments;

  int get settledInstallments => _settledInstallments;

  PaymentSource get source =>
      (walletId: _cardId == null ? _walletId : null, cardId: _cardId);

  CreditCard? get card {
    for (final card in _cards) {
      if (card.id == _cardId) return card;
    }
    return null;
  }

  bool get isSaving => _isSaving;

  bool get isInstallment => _type == ExpenseType.installment;

  int get remainingInstallments => _totalInstallments - _settledInstallments;

  double get totalCommitted =>
      isInstallment ? _amount * remainingInstallments : _amount;

  Month get lastMonth => isInstallment
      ? startMonth.addMonths(remainingInstallments - 1)
      : startMonth;

  bool get isValid =>
      _name.trim().isNotEmpty &&
      _amount > 0 &&
      !endsBeforeStart &&
      (!isInstallment || remainingInstallments > 0);

  /// Paid months the edited rule would stop projecting, leaving out those the
  /// saved rule already did not project.
  Set<Month> get monthsLeftOffRule {
    final expense = _expense;
    if (expense == null || _payments.isEmpty) return const <Month>{};

    final paidMonths = _payments.map((payment) => payment.month);
    return _draft
        .monthsOffRule(paidMonths)
        .difference(expense.monthsOffRule(paidMonths));
  }

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
    if (value != ExpenseType.recurring) {
      _endMonth = null;
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

  void setPurchasedAt(DateTime value) {
    _purchasedAt = _dayOf(value);
    notifyListeners();
  }

  void setEndMonth(Month? value) {
    _endMonth = value;
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

  void setSource(PaymentSource value) {
    _walletId = value.walletId;
    _cardId = value.cardId;
    final card = this.card;
    if (card != null && !isEditing) {
      _startMonth = card.invoiceMonthFor(_purchasedAt ?? _now);
    }
    notifyListeners();
  }

  Future<void> save() async {
    if (!isValid || _isSaving) return;
    _isSaving = true;
    notifyListeners();

    await _repository.saveExpense(_draft);

    _isSaving = false;
    notifyListeners();
  }

  Expense get _draft {
    final card = this.card;
    return Expense(
      id: _expense?.id,
      name: _name.trim(),
      type: _type,
      amount: _amount,
      dueDay: card?.dueDay ?? _dueDay,
      startMonth: startMonth,
      endMonth: _type == ExpenseType.recurring ? _endMonth : null,
      totalInstallments: isInstallment ? _totalInstallments : null,
      settledInstallments: isInstallment ? _settledInstallments : 0,
      walletId: card == null ? _walletId : card.walletId,
      cardId: card?.id,
      purchasedAt: card == null ? null : _purchasedAt,
      createdAt: _expense?.createdAt ?? _now,
    );
  }

  static DateTime _dayOf(DateTime date) =>
      DateTime(date.year, date.month, date.day);
}
