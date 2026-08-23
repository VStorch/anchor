import 'package:sqflite/sqflite.dart';

import '../../../core/database/app_database.dart';
import '../../../core/state/data_changes.dart';
import '../../../core/utils/month.dart';
import '../models/expense.dart';
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

  Future<void> saveExpense(Expense expense) async {
    final db = await _database.database;
    await db.insert(
      AppDatabase.expensesTable,
      expense.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _changes.publish();
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
    final rows = await db.query(AppDatabase.expensePaymentsTable);
    return rows.map(ExpensePayment.fromMap).toList();
  }

  Future<void> savePayment(ExpensePayment payment) async {
    final db = await _database.database;
    await db.insert(
      AppDatabase.expensePaymentsTable,
      payment.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _changes.publish();
  }

  Future<void> deletePayment(int expenseId, Month month) async {
    final db = await _database.database;
    await db.delete(
      AppDatabase.expensePaymentsTable,
      where: 'expense_id = ? AND month_key = ?',
      whereArgs: [expenseId, month.key],
    );
    _changes.publish();
  }
}
