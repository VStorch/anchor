import 'package:anchor/core/database/app_database.dart';
import 'package:anchor/core/state/data_changes.dart';
import 'package:anchor/core/utils/month.dart';
import 'package:anchor/features/budget/services/budget_service.dart';
import 'package:anchor/features/cards/repositories/card_repository.dart';
import 'package:anchor/features/expenses/models/expense.dart';
import 'package:anchor/features/expenses/models/expense_payment.dart';
import 'package:anchor/features/expenses/models/expense_type.dart';
import 'package:anchor/features/expenses/repositories/expense_repository.dart';
import 'package:anchor/features/reminders/viewmodels/reminders_view_model.dart';
import 'package:anchor/features/wallets/repositories/wallet_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_reminder_notifications.dart';
import '../../support/test_database.dart';

void main() {
  late AppDatabase database;
  late DataChanges changes;
  late ExpenseRepository expenses;
  late FakeReminderNotifications notifications;

  final today = DateTime.now();
  final month = Month.fromDate(today);
  final clock = DateTime(today.year, today.month, 1, 8);

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    database = createInMemoryDatabase();
    changes = DataChanges();
    expenses = ExpenseRepository(database, changes);
    notifications = FakeReminderNotifications();
  });

  tearDown(() => database.close());

  RemindersViewModel buildViewModel() => RemindersViewModel(
    budgetService: BudgetService(
      expenses,
      WalletRepository(database, changes),
      CardRepository(database, changes),
    ),
    notifications: notifications,
    changes: changes,
    clock: () => clock,
  );

  Future<int> seedRent() async {
    await expenses.saveExpense(
      Expense(
        name: 'Aluguel',
        type: ExpenseType.recurring,
        amount: 1200,
        dueDay: 10,
        startMonth: month,
        createdAt: clock,
      ),
    );
    return (await expenses.fetchExpenses()).single.id!;
  }

  test('agenda o aviso e pede permissão só na primeira conta', () async {
    await seedRent();
    final viewModel = buildViewModel();
    await viewModel.initialize();

    expect(notifications.permissionRequests, 1);
    expect(notifications.scheduled.first.title, 'Aluguel vence hoje');
    expect(
      notifications.scheduled.first.at,
      DateTime(clock.year, clock.month, 10, 9),
    );

    changes.publish();
    await viewModel.idle;
    expect(notifications.permissionRequests, 1);
  });

  test('pagar a conta cancela o aviso dela', () async {
    final rentId = await seedRent();
    final viewModel = buildViewModel();
    await viewModel.initialize();
    final before = notifications.scheduled.length;

    await expenses.savePayment(
      ExpensePayment(
        expenseId: rentId,
        month: month,
        amount: 1200,
        paidAt: clock,
      ),
    );
    await viewModel.idle;

    expect(notifications.scheduled, hasLength(before - 1));
    expect(
      notifications.scheduled.every((r) => r.at.month != clock.month),
      isTrue,
    );
  });

  test('negar a permissão desliga os lembretes', () async {
    await seedRent();
    notifications.grantsPermission = false;
    final viewModel = buildViewModel();
    await viewModel.initialize();

    expect(viewModel.isEnabled, isFalse);
    expect(notifications.scheduled, isEmpty);

    changes.publish();
    await viewModel.idle;
    expect(notifications.permissionRequests, 1);
  });

  test('desligar no Ajustes limpa o que estava agendado', () async {
    await seedRent();
    final viewModel = buildViewModel();
    await viewModel.initialize();
    expect(notifications.scheduled, isNotEmpty);

    await viewModel.setEnabled(false);

    expect(viewModel.isEnabled, isFalse);
    expect(notifications.scheduled, isEmpty);
  });
}
