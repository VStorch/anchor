import 'package:flutter/foundation.dart';

import '../../../core/utils/money.dart';
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
       _referenceMonth = referenceMonth,
       _openedInvoiceMonth = invoiceMonth,
       _cards = cards,
       _expense = expense,
       _payments = payments,
       _name = expense?.name ?? '',
       _type =
           expense?.type ??
           (card == null ? ExpenseType.recurring : ExpenseType.single),
       _amount = expense?.amount ?? 0,
       _dueDay = expense?.dueDay,
       _startMonth = expense?.startMonth ?? referenceMonth,
       _endMonth = expense?.type == ExpenseType.recurring
           ? expense?.endMonth
           : null,
       _totalInstallments = expense?.totalInstallments,
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
  final Month _referenceMonth;

  String _name;
  ExpenseType _type;
  double _amount;
  int? _dueDay;
  Month _startMonth;
  Month? _endMonth;
  int? _totalInstallments;
  int _settledInstallments;
  int? _walletId;
  int? _cardId;
  DateTime? _purchasedAt;
  bool _isSaving = false;

  bool get isEditing => _expense != null;

  String get name => _name;

  ExpenseType get type => _type;

  double get amount => _amount;

  int? get dueDay => _dueDay;

  /// A new bill has no due day until the user picks one; a card purchase
  /// takes the card's.
  bool get needsDueDay => card == null && _dueDay == null;

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

  /// Null until the user says how many: no count is assumed for them.
  int? get totalInstallments => _totalInstallments;

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

  int get remainingInstallments =>
      (validTotalInstallments ?? 0) - _settledInstallments;

  double get totalCommitted =>
      isInstallment ? _amount * remainingInstallments : _amount;

  Month get lastMonth => isInstallment
      ? startMonth.addMonths(remainingInstallments - 1)
      : startMonth;

  bool get isValid =>
      _name.trim().isNotEmpty &&
      _amount > 0 &&
      !endsBeforeStart &&
      !needsDueDay &&
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
      ? 'Faltam $remainingInstallments parcelas até '
            '${lastMonth.label.toLowerCase()}'
      : null;

  /// Which parcel the month on screen gets, or when the first one to pay is
  /// due if that is later: "Setembro de 2026 será a parcela 4 de 10".
  String? get installmentPreview {
    if (!isInstallment || remainingInstallments <= 0) return null;

    final parcel = _draft.occurrenceIn(_referenceMonth)?.installmentNumber;
    if (parcel != null) {
      return '${_referenceMonth.label} será a parcela $parcel de '
          '$_totalInstallments';
    }
    final next = _settledInstallments + 1;
    return _referenceMonth < startMonth
        ? 'A parcela $next de $_totalInstallments vence em '
              '${startMonth.label.toLowerCase()}'
        : 'A última parcela vence em ${lastMonth.label.toLowerCase()}';
  }

  void setName(String value) {
    _name = value;
    notifyListeners();
  }

  void setType(ExpenseType value) {
    if (_type == value) return;
    final wasInstallment = isInstallment;
    final price = !wasInstallment
        ? _amount
        : entersPurchaseTotal
        ? _purchaseTotal
        : (storedTotal ?? _amount);
    _type = value;
    if (isPurchase && isInstallment) {
      _entersTotal = true;
      _purchaseTotal = price;
      _amount = _parcelOfTotal();
    } else if (isPurchase && wasInstallment) {
      _amount = price;
    }
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

  static const int minInstallments = 2;
  static const int maxInstallments = 480;

  /// Kept exactly as typed: an out-of-range count is shown as an error, never
  /// silently changed into another number.
  void setTotalInstallments(int? value) {
    _totalInstallments = value;
    if (entersPurchaseTotal) _amount = _parcelOfTotal();
    final total = validTotalInstallments;
    if (total != null && _settledInstallments >= total) {
      _settledInstallments = total - 1;
    }
    notifyListeners();
  }

  void setSettledInstallments(int value) {
    final total = validTotalInstallments;
    _settledInstallments = total == null ? 0 : value.clamp(0, total - 1);
    notifyListeners();
  }

  int? get validTotalInstallments {
    final total = _totalInstallments;
    if (total == null || total < minInstallments || total > maxInstallments) {
      return null;
    }
    return total;
  }

  /// What the total field says is wrong, or null.
  String? get totalInstallmentsError {
    if (!isInstallment || _totalInstallments == null) return null;
    return validTotalInstallments == null
        ? 'De $minInstallments a $maxInstallments parcelas'
        : null;
  }

  /// A card purchase started from the card itself, not an edit.
  bool get isNewPurchase => !isEditing && card != null;

  /// Anything charged to a card reads as a purchase: "O que comprou",
  /// "À vista" or "Parcelado".
  bool get isPurchase => card != null;

  /// A purchase is paid à vista, in parcels, or every month (a streaming
  /// subscription on the card).
  List<ExpenseType> get typeOptions => isPurchase
      ? const [
          ExpenseType.single,
          ExpenseType.installment,
          ExpenseType.recurring,
        ]
      : ExpenseType.values;

  String typeLabel(ExpenseType type) => !isPurchase
      ? type.label
      : switch (type) {
          ExpenseType.single => 'À vista',
          ExpenseType.installment => 'Parcelado',
          ExpenseType.recurring => type.label,
        };

  String typeDescription(ExpenseType type) => !isPurchase
      ? type.description
      : switch (type) {
          ExpenseType.single => 'Entra inteira numa fatura',
          ExpenseType.installment => 'Dividida em parcelas nas faturas',
          ExpenseType.recurring => 'Assinaturas, como streaming',
        };

  /// A purchase in parcels is typed by its total price, as the receipt shows
  /// it; the parcel stored is the total over the count, to the cent. An
  /// existing purchase already in parcels opens on its parcel value.
  late bool _entersTotal = _expense?.type != ExpenseType.installment;
  double _purchaseTotal = 0;

  bool get entersPurchaseTotal => isPurchase && isInstallment && _entersTotal;

  double get purchaseTotal => _purchaseTotal;

  /// Switching between total and parcel converts what was typed: the total
  /// is the parcel times the count, the parcel the total over it. Without a
  /// valid count the number carries over as it is.
  void setEntersPurchaseTotal(bool value) {
    if (value == _entersTotal) return;
    final count = validTotalInstallments;
    if (value) {
      _purchaseTotal = count == null ? _amount : roundCents(_amount * count);
      _entersTotal = true;
      _amount = count == null ? _amount : _parcelOfTotal();
    } else {
      _entersTotal = false;
      _amount = count == null ? _purchaseTotal : _parcelOfTotal();
    }
    notifyListeners();
  }

  void setPurchaseTotal(double value) {
    _purchaseTotal = value;
    _amount = _parcelOfTotal();
    notifyListeners();
  }

  double _parcelOfTotal() {
    final count = validTotalInstallments;
    if (count == null || _purchaseTotal <= 0) return 0;
    return roundCents(_purchaseTotal / count);
  }

  /// What the parcels add up to once stored: the parcel times the count,
  /// which is what the invoices will charge.
  double? get storedTotal {
    final count = validTotalInstallments;
    if (count == null || _amount <= 0) return null;
    return roundCents(_amount * count);
  }

  /// "10x de R$ 83,33", under the total price — and, when the total does
  /// not divide to the cent, the total the parcels really add up to:
  /// "3x de R$ 333,33 (total R$ 999,99)". The typed total is never shown as
  /// if it were stored.
  String? get parcelPreview {
    final stored = storedTotal;
    if (!entersPurchaseTotal || stored == null) return null;
    final parcels = '${validTotalInstallments}x de ${formatMoney(_amount)}';
    return sameAmount(stored, _purchaseTotal)
        ? parcels
        : '$parcels (total ${formatMoney(stored)})';
  }

  /// What the disabled save button asks for.
  bool get needsInstallmentCount => isInstallment && _totalInstallments == null;

  /// The installment details only make sense once the count is valid.
  bool get showsInstallmentPlan =>
      !isInstallment || validTotalInstallments != null;

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
      dueDay: card?.dueDay ?? _dueDay ?? 1,
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
