import 'package:flutter/foundation.dart';

import '../../../core/utils/month.dart';
import '../../reminders/models/reminder_lead.dart';
import '../../reminders/viewmodels/reminders_view_model.dart';
import '../../settings/viewmodels/settings_view_model.dart';
import '../../wallets/models/wallet_kind.dart';
import '../models/onboarding_draft.dart';
import '../services/onboarding_service.dart';

enum OnboardingStep {
  welcome,
  income,
  balance,
  bills,
  installments,
  card,
  reminders,
}

class OnboardingViewModel extends ChangeNotifier {
  OnboardingViewModel({
    required OnboardingService service,
    required SettingsViewModel settings,
    required RemindersViewModel reminders,
    DateTime Function() clock = DateTime.now,
  }) : _service = service,
       _settings = settings,
       _reminders = reminders,
       _clock = clock,
       _lead = reminders.lead;

  final OnboardingService _service;
  final SettingsViewModel _settings;
  final RemindersViewModel _reminders;
  final DateTime Function() _clock;

  final IncomeDraft salary = IncomeDraft(
    kind: WalletKind.salary,
    name: WalletKind.salary.label,
  );
  final IncomeDraft benefit = IncomeDraft(kind: WalletKind.benefit);
  bool? _hasBenefit;
  final List<BillDraft> _bills = <BillDraft>[];
  final List<InstallmentDraft> _installments = <InstallmentDraft>[];
  final CardDraft card = CardDraft();
  bool? _hasCard;
  ReminderLead _lead;

  final Set<OnboardingStep> _skipped = <OnboardingStep>{};
  OnboardingStep _step = OnboardingStep.welcome;
  bool _isSaving = false;

  OnboardingStep get step => _step;

  DateTime get today => _clock();

  Month get month => Month.fromDate(today);

  bool get isSaving => _isSaving;

  bool get isFirstStep => _step == OnboardingStep.welcome;

  /// How far along the steps the user is, from 0 to 1.
  double get progress =>
      _step.index / (OnboardingStep.values.length - 1).toDouble();

  bool? get hasBenefit => _hasBenefit;

  bool? get hasCard => _hasCard;

  ReminderLead get lead => _lead;

  List<BillDraft> get bills => List<BillDraft>.unmodifiable(_bills);

  List<InstallmentDraft> get installments =>
      List<InstallmentDraft>.unmodifiable(_installments);

  /// The sources registered so far, in the order they become wallets.
  List<IncomeDraft> get incomes => _skipped.contains(OnboardingStep.income)
      ? const <IncomeDraft>[]
      : [
          if (salary.isComplete) salary,
          if (_hasBenefit == true && benefit.isComplete) benefit,
        ];

  bool isSuggestionPicked(String name) =>
      _bills.any((bill) => bill.isSuggestion && bill.name == name);

  /// Why the step cannot move on yet, or null when it can.
  String? get blocker => switch (_step) {
    OnboardingStep.welcome || OnboardingStep.reminders => null,
    OnboardingStep.income => _incomeBlocker,
    OnboardingStep.balance => _balanceBlocker,
    OnboardingStep.bills => _bills.map(_billBlocker).nonNulls.firstOrNull,
    OnboardingStep.installments =>
      _installments.map(_installmentBlocker).nonNulls.firstOrNull,
    OnboardingStep.card => _cardBlocker,
  };

  bool get canContinue => blocker == null && !_isSaving;

  String? get _incomeBlocker {
    for (final income in [salary, if (_hasBenefit == true) benefit]) {
      final name = income.kind == WalletKind.salary
          ? 'do salário'
          : 'do benefício';
      if (income.amount <= 0) return 'Informe o valor $name';
      if (income.day == null) return 'Escolha o dia $name';
    }
    if (_hasBenefit == null) return 'Responda sobre o benefício';
    return null;
  }

  String? get _balanceBlocker {
    for (final income in incomes) {
      if (income.balanceToday == null) {
        return 'Informe quanto tem em ${income.displayName}';
      }
      if (income.isDueBy(today) && income.arrived == null) {
        return 'Responda se o dinheiro já caiu';
      }
    }
    return null;
  }

  String? _billBlocker(BillDraft bill) {
    final name = bill.name.trim();
    if (name.isEmpty) return 'Dê um nome à conta';
    if (bill.amount <= 0) return 'Informe o valor de $name';
    if (bill.dueDay == null) return 'Escolha o vencimento de $name';
    return null;
  }

  String? _installmentBlocker(InstallmentDraft installment) {
    final name = installment.name.trim();
    if (name.isEmpty) return 'Dê um nome à compra';
    if (installment.amount <= 0) return 'Informe o valor da parcela de $name';
    if (!installment.hasValidNumbers) return 'Confira as parcelas de $name';
    if (installment.dueDay == null) return 'Escolha o vencimento de $name';
    return null;
  }

  String? get _cardBlocker {
    if (_hasCard != true) {
      return _hasCard == null ? 'Responda sobre o cartão' : null;
    }
    if (card.name.trim().isEmpty) return 'Dê um nome ao cartão';
    if (card.closingDay == null) return 'Escolha o dia do fechamento';
    if (card.dueDay == null) return 'Escolha o dia do vencimento';
    return null;
  }

  /// Applies a change made to one of the drafts and redraws.
  void edit(VoidCallback change) {
    change();
    notifyListeners();
  }

  void setHasBenefit(bool value) => edit(() => _hasBenefit = value);

  void setHasCard(bool value) => edit(() {
    _hasCard = value;
    card.payer ??= incomes.isEmpty ? null : incomes.first;
  });

  void setLead(ReminderLead value) => edit(() => _lead = value);

  void toggleSuggestion(String name) => edit(() {
    final picked = _bills.indexWhere(
      (bill) => bill.isSuggestion && bill.name == name,
    );
    if (picked >= 0) {
      _bills.removeAt(picked);
    } else {
      _bills.add(BillDraft(name: name, isSuggestion: true));
    }
  });

  void addOtherBill() => edit(() => _bills.add(BillDraft()));

  void removeBill(BillDraft bill) => edit(() => _bills.remove(bill));

  void addInstallment() => edit(() => _installments.add(InstallmentDraft()));

  void removeInstallment(InstallmentDraft installment) =>
      edit(() => _installments.remove(installment));

  void next() {
    if (!canContinue || _step == OnboardingStep.reminders) return;
    _skipped.remove(_step);
    _moveTo(_following(_step));
  }

  void skipStep() {
    if (_step == OnboardingStep.reminders) return;
    _skipped.add(_step);
    if (_step == OnboardingStep.balance) {
      for (final income in [salary, benefit]) {
        income.balanceToday = null;
        income.arrived = null;
        income.monthlyReserve = null;
      }
    }
    _moveTo(_following(_step));
  }

  void back() {
    if (isFirstStep) return;
    var previous = OnboardingStep.values[_step.index - 1];
    if (!_applies(previous)) {
      previous = OnboardingStep.values[previous.index - 1];
    }
    _moveTo(previous);
  }

  OnboardingStep _following(OnboardingStep step) {
    var next = OnboardingStep.values[step.index + 1];
    if (!_applies(next)) next = OnboardingStep.values[next.index + 1];
    return next;
  }

  bool _applies(OnboardingStep step) =>
      step != OnboardingStep.balance || incomes.isNotEmpty;

  void _moveTo(OnboardingStep step) {
    _step = step;
    notifyListeners();
  }

  OnboardingDraft get draft {
    bool kept(OnboardingStep step) => !_skipped.contains(step);
    return OnboardingDraft(
      incomes: incomes,
      bills: kept(OnboardingStep.bills)
          ? _bills.where((bill) => bill.isComplete).toList()
          : const <BillDraft>[],
      installments: kept(OnboardingStep.installments)
          ? _installments.where((item) => item.isComplete).toList()
          : const <InstallmentDraft>[],
      card: kept(OnboardingStep.card) && _hasCard == true && card.isComplete
          ? card
          : null,
    );
  }

  /// Something typed that "Pular configuração" would throw away.
  bool get hasAnswers =>
      salary.amount > 0 ||
      salary.day != null ||
      _bills.isNotEmpty ||
      _installments.isNotEmpty ||
      _hasBenefit == true ||
      _hasCard == true;

  /// Leaves the first run without saving anything.
  Future<void> skipSetup() => _settings.markOnboardingDone();

  /// Android asks for the notification permission here, with the reminders
  /// on screen, and never again on its own. Everything is saved after it.
  Future<void> finish({required bool withReminders}) async {
    if (_isSaving) return;
    _isSaving = true;
    notifyListeners();

    try {
      if (withReminders) {
        await _reminders.setLead(_lead);
        await _reminders.setEnabled(true);
      } else {
        await _reminders.setEnabled(false);
      }
      await _service.apply(draft, now: _clock());
    } catch (_) {
      _isSaving = false;
      notifyListeners();
      rethrow;
    }
    await _settings.markOnboardingDone();
  }
}
