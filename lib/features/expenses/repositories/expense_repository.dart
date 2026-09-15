import 'package:sqflite/sqflite.dart';

import '../../../core/database/app_database.dart';
import '../../../core/state/data_changes.dart';
import '../../../core/utils/month.dart';
import '../models/expense.dart';
import '../models/expense_month.dart';
import '../models/expense_payment.dart';

class ExpenseRepository {
  ExpenseRepository(this._database, this._changes);

  final AppDatabase _database;
  final DataChanges _changes;

  Future<List<Expense>> fetchExpenses() async {
    final db = await _database.database;
    final rows = await db.query(
      AppDatabase.expensesTable,
      orderBy: 'due_day ASC, name ASC',
    );
    return rows.map(Expense.fromMap).toList();
  }

  Future<int> saveExpense(Expense expense) async {
    final db = await _database.database;
    final values = expense.toMap();

    final id = expense.id ?? await db.insert(AppDatabase.expensesTable, values);
    if (expense.id != null) {
      await db.update(
        AppDatabase.expensesTable,
        values,
        where: 'id = ?',
        whereArgs: [id],
      );
    }
    _changes.publish();
    return id;
  }

  Future<void> deleteExpense(int id) async {
    final db = await _database.database;
    await db.delete(
      AppDatabase.expensesTable,
      where: 'id = ?',
      whereArgs: [id],
    );
    _changes.publish();
  }

  Future<List<ExpensePayment>> fetchPayments() async {
    final db = await _database.database;
    final rows = await db.query(
      AppDatabase.expensePaymentsTable,
      orderBy: 'paid_at ASC, id ASC',
    );
    return rows.map(ExpensePayment.fromMap).toList();
  }

  Future<void> savePayment(ExpensePayment payment) async {
    final db = await _database.database;
    if (payment.id == null) {
      await db.insert(AppDatabase.expensePaymentsTable, payment.toMap());
    } else {
      await db.update(
        AppDatabase.expensePaymentsTable,
        payment.toMap(),
        where: 'id = ?',
        whereArgs: [payment.id],
      );
    }
    _changes.publish();
  }

  Future<void> savePayments(List<ExpensePayment> payments) async {
    if (payments.isEmpty) return;
    final db = await _database.database;
    final batch = db.batch();
    for (final payment in payments) {
      batch.insert(AppDatabase.expensePaymentsTable, payment.toMap());
    }
    await batch.commit(noResult: true);
    _changes.publish();
  }

  Future<void> deletePaymentsOfMany(List<int> expenseIds, Month month) async {
    if (expenseIds.isEmpty) return;
    final db = await _database.database;
    await db.delete(
      AppDatabase.expensePaymentsTable,
      where:
          'month_key = ? AND expense_id IN (${List.filled(expenseIds.length, '?').join(', ')})',
      whereArgs: [month.key, ...expenseIds],
    );
    _changes.publish();
  }

  Future<void> deletePayment(int id) async {
    final db = await _database.database;
    await db.delete(
      AppDatabase.expensePaymentsTable,
      where: 'id = ?',
      whereArgs: [id],
    );
    _changes.publish();
  }

  Future<void> deletePaymentsOf(int expenseId, Month month) async {
    final db = await _database.database;
    await db.delete(
      AppDatabase.expensePaymentsTable,
      where: 'expense_id = ? AND month_key = ?',
      whereArgs: [expenseId, month.key],
    );
    _changes.publish();
  }

  Future<List<ExpenseMonth>> fetchMonthAmounts() async {
    final db = await _database.database;
    final rows = await db.query(AppDatabase.expenseMonthsTable);
    return rows.map(ExpenseMonth.fromMap).toList();
  }

  Future<void> saveMonthAmount(ExpenseMonth monthAmount) async {
    final db = await _database.database;
    await db.insert(
      AppDatabase.expenseMonthsTable,
      monthAmount.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _changes.publish();
  }

  Future<void> clearMonthAmount(int expenseId, Month month) async {
    final db = await _database.database;
    await db.delete(
      AppDatabase.expenseMonthsTable,
      where: 'expense_id = ? AND month_key = ?',
      whereArgs: [expenseId, month.key],
    );
    _changes.publish();
  }
}
