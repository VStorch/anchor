import 'package:anchor/core/database/app_database.dart';
import 'package:anchor/core/state/data_changes.dart';
import 'package:anchor/core/utils/month.dart';
import 'package:anchor/features/budget/services/budget_service.dart';
import 'package:anchor/features/cards/repositories/card_repository.dart';
import 'package:anchor/features/expenses/repositories/expense_repository.dart';
import 'package:anchor/features/onboarding/services/onboarding_service.dart';
import 'package:anchor/features/onboarding/viewmodels/onboarding_view_model.dart';
import 'package:anchor/features/reminders/models/reminder_lead.dart';
import 'package:anchor/features/reminders/viewmodels/reminders_view_model.dart';
import 'package:anchor/features/settings/viewmodels/settings_view_model.dart';
import 'package:anchor/features/wallets/models/payout_schedule.dart';
import 'package:anchor/features/wallets/repositories/wallet_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_reminder_notifications.dart';
import '../../support/test_database.dart';

void main() {
  const september = Month(2026, 9);
  final now = DateTime(2026, 9, 15, 10);

  late AppDatabase database;
  late BudgetService budget;
  late SettingsViewModel settings;
  late FakeReminderNotifications notifications;
  late RemindersViewModel reminders;
  late OnboardingViewModel viewModel;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    database = createInMemoryDatabase();
    final changes = DataChanges();
    final wallets = WalletRepository(database, changes);
    final expenses = ExpenseRepository(database, changes);
    final cards = CardRepository(database, changes);
    budget = BudgetService(expenses, wallets, cards, clock: () => now);
    settings = SettingsViewModel();
    await settings.initialize();
    notifications = FakeReminderNotifications();
    reminders = RemindersViewModel(
      budgetService: budget,
      notifications: notifications,
      changes: changes,
      clock: () => now,
    );
    await reminders.initialize();
    viewModel = OnboardingViewModel(
      service: OnboardingService(
        wallets: wallets,
        expenses: expenses,
        cards: cards,
        budget: budget,
        changes: changes,
      ),
      settings: settings,
      reminders: reminders,
      clock: () => now,
    );
  });

  tearDown(() => database.close());

  void fillSalary({int day = 5}) {
    viewModel.next();
    viewModel.edit(() {
      viewModel.salary
        ..amount = 3200
        ..schedule = PayoutSchedule.businessDay
        ..day = day;
    });
    viewModel.setHasBenefit(false);
  }

  test(
    'o passo de renda só segue com valor, dia e a resposta do benefício',
    () {
      viewModel.next();
      expect(viewModel.step, OnboardingStep.income);
      expect(viewModel.blocker, 'Informe o valor do salário');

      viewModel.edit(() => viewModel.salary.amount = 3200);
      expect(viewModel.blocker, 'Escolha o dia do salário');

      viewModel.edit(() => viewModel.salary.day = 5);
      expect(viewModel.blocker, 'Responda sobre o benefício');

      viewModel.setHasBenefit(true);
      expect(viewModel.blocker, 'Informe o valor do benefício');

      viewModel.setHasBenefit(false);
      expect(viewModel.canContinue, isTrue);
      viewModel.next();
      expect(viewModel.step, OnboardingStep.balance);
    },
  );

  test('pergunta se o salário caiu só quando a data dele já chegou', () {
    fillSalary();
    viewModel.next();

    viewModel.edit(() => viewModel.salary.balanceToday = 850);
    expect(viewModel.blocker, 'Responda se o dinheiro já caiu');

    viewModel.edit(() => viewModel.salary.arrived = true);
    expect(viewModel.canContinue, isTrue);

    viewModel.back();
    viewModel.edit(() => viewModel.salary.day = 20);
    viewModel.next();
    viewModel.edit(() => viewModel.salary.arrived = null);
    expect(viewModel.salary.isDueBy(now), isFalse);
    expect(viewModel.canContinue, isTrue);
  });

  test('pular o saldo de hoje descarta também a reserva digitada', () {
    fillSalary();
    viewModel.next();
    viewModel.edit(() {
      viewModel.salary.balanceToday = 850;
      viewModel.salary.monthlyReserve = 500;
    });

    viewModel.skipStep();

    expect(viewModel.salary.balanceToday, isNull);
    expect(viewModel.salary.monthlyReserve, isNull);
    expect(viewModel.draft.incomes.single.monthlyReserve, isNull);
  });

  test('pular a renda pula também o saldo de hoje', () {
    viewModel.next();
    viewModel.skipStep();

    expect(viewModel.step, OnboardingStep.bills);
    expect(viewModel.incomes, isEmpty);

    viewModel.back();
    expect(viewModel.step, OnboardingStep.income);
  });

  test('uma conta sugerida precisa de valor e vencimento', () {
    fillSalary();
    viewModel.next();
    viewModel.skipStep();
    expect(viewModel.step, OnboardingStep.bills);

    viewModel.toggleSuggestion('Aluguel');
    expect(viewModel.isSuggestionPicked('Aluguel'), isTrue);
    expect(viewModel.blocker, 'Informe o valor de Aluguel');

    final rent = viewModel.bills.single;
    viewModel.edit(() => rent.amount = 1100);
    expect(viewModel.blocker, 'Escolha o vencimento de Aluguel');

    viewModel.edit(() => rent.dueDay = 10);
    expect(viewModel.canContinue, isTrue);
    expect(rent.isPastDueBy(now), isTrue);
    expect(rent.paidThisMonth, isTrue);

    viewModel.toggleSuggestion('Aluguel');
    expect(viewModel.bills, isEmpty);
  });

  test('a parcela atual não passa do total', () {
    fillSalary();
    viewModel
      ..next()
      ..skipStep()
      ..skipStep();
    expect(viewModel.step, OnboardingStep.installments);

    viewModel.addInstallment();
    final fridge = viewModel.installments.single;
    viewModel.edit(() {
      fridge
        ..name = 'Geladeira'
        ..amount = 180
        ..currentNumber = 11
        ..total = 10
        ..dueDay = 5;
    });
    expect(viewModel.blocker, 'Confira as parcelas de Geladeira');

    viewModel.edit(() => fridge.currentNumber = 4);
    expect(viewModel.canContinue, isTrue);
    expect(fridge.settledInstallments, 3);
  });

  test('concluir salva o rascunho, os lembretes e não volta a abrir', () async {
    fillSalary();
    viewModel.next();
    viewModel.edit(() {
      viewModel.salary
        ..balanceToday = 850
        ..arrived = true;
    });
    viewModel.next();
    viewModel.toggleSuggestion('Aluguel');
    viewModel.edit(() {
      viewModel.bills.single
        ..amount = 1100
        ..dueDay = 10;
    });
    viewModel
      ..next()
      ..skipStep();
    viewModel.setHasCard(false);
    viewModel.next();
    expect(viewModel.step, OnboardingStep.reminders);

    viewModel.setLead(ReminderLead.dayBefore);
    await viewModel.finish(withReminders: true);
    await reminders.idle;

    expect(settings.onboardingDone, isTrue);
    expect(reminders.lead, ReminderLead.dayBefore);
    expect(notifications.permissionRequests, 1);

    final snapshot = await budget.loadSnapshot(september);
    expect(snapshot.walletsBalance, 850);
    expect(snapshot.summary.occurrences.single.isPaid, isTrue);

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getBool('onboarding_done'), isTrue);
  });

  test('sem lembretes, o Android não é consultado', () async {
    fillSalary();
    viewModel
      ..next()
      ..skipStep();
    viewModel.toggleSuggestion('Luz');
    viewModel.edit(() {
      viewModel.bills.single
        ..amount = 150
        ..dueDay = 20;
    });
    viewModel
      ..next()
      ..skipStep()
      ..skipStep();

    await viewModel.finish(withReminders: false);
    await reminders.idle;

    expect(notifications.permissionRequests, 0);
    expect(notifications.scheduled, isEmpty);
    expect(reminders.isEnabled, isFalse);
  });

  test('pular a configuração não grava nada', () async {
    fillSalary();

    expect(viewModel.hasAnswers, isTrue);
    await viewModel.skipSetup();

    expect(settings.onboardingDone, isTrue);
    final snapshot = await budget.loadSnapshot(september);
    expect(snapshot.isBlank, isTrue);
  });
}
