import 'dart:io';

import 'package:anchor/core/database/app_database.dart';
import 'package:anchor/core/state/data_changes.dart';
import 'package:anchor/core/utils/month.dart';
import 'package:anchor/features/expenses/models/expense_payment.dart';
import 'package:anchor/features/expenses/repositories/expense_repository.dart';
import 'package:anchor/features/wallets/models/payout_schedule.dart';
import 'package:anchor/features/wallets/models/receipt_kind.dart';
import 'package:anchor/features/wallets/models/receipt_status.dart';
import 'package:anchor/features/wallets/repositories/wallet_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../support/test_database.dart';

const List<String> _schemaV1 = <String>[
  '''
  CREATE TABLE wallets (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    kind TEXT NOT NULL,
    color_index INTEGER NOT NULL,
    created_at TEXT NOT NULL
  )
  ''',
  '''
  CREATE TABLE payouts (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    wallet_id INTEGER NOT NULL REFERENCES wallets(id) ON DELETE CASCADE,
    label TEXT NOT NULL,
    amount REAL NOT NULL,
    day_of_month INTEGER NOT NULL
  )
  ''',
  '''
  CREATE TABLE receipts (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    wallet_id INTEGER NOT NULL REFERENCES wallets(id) ON DELETE CASCADE,
    payout_id INTEGER REFERENCES payouts(id) ON DELETE SET NULL,
    month_key TEXT NOT NULL,
    amount REAL NOT NULL,
    received_at TEXT NOT NULL
  )
  ''',
  'CREATE UNIQUE INDEX idx_receipt_payout_month ON receipts(payout_id, month_key)',
  '''
  CREATE TABLE expenses (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    type TEXT NOT NULL,
    amount REAL NOT NULL,
    due_day INTEGER NOT NULL,
    start_month TEXT NOT NULL,
    end_month TEXT,
    total_installments INTEGER,
    settled_installments INTEGER NOT NULL DEFAULT 0,
    wallet_id INTEGER REFERENCES wallets(id) ON DELETE SET NULL,
    created_at TEXT NOT NULL
  )
  ''',
  '''
  CREATE TABLE expense_payments (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    expense_id INTEGER NOT NULL REFERENCES expenses(id) ON DELETE CASCADE,
    wallet_id INTEGER REFERENCES wallets(id) ON DELETE SET NULL,
    month_key TEXT NOT NULL,
    amount REAL NOT NULL,
    paid_at TEXT NOT NULL
  )
  ''',
  'CREATE UNIQUE INDEX idx_payment_expense_month ON expense_payments(expense_id, month_key)',
];

void main() {
  late Directory directory;
  late String path;

  setUp(() async {
    createInMemoryDatabase();
    directory = await Directory.systemTemp.createTemp('anchor_migration');
    path = '${directory.path}/anchor.db';

    final db = await databaseFactoryFfiNoIsolate.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) async {
          for (final statement in _schemaV1) {
            await db.execute(statement);
          }
        },
      ),
    );

    await db.insert('wallets', <String, Object?>{
      'name': 'Salário',
      'kind': 'salary',
      'color_index': 0,
      'created_at': DateTime(2026, 8).toIso8601String(),
    });
    await db.insert('payouts', <String, Object?>{
      'wallet_id': 1,
      'label': 'Mensal',
      'amount': 3000.0,
      'day_of_month': 5,
    });
    await db.insert('receipts', <String, Object?>{
      'wallet_id': 1,
      'payout_id': 1,
      'month_key': '2026-08',
      'amount': 3000.0,
      'received_at': DateTime(2026, 8, 5).toIso8601String(),
    });
    await db.insert('expenses', <String, Object?>{
      'name': 'Mercado',
      'type': 'recurring',
      'amount': 600.0,
      'due_day': 10,
      'start_month': '2026-08',
      'settled_installments': 0,
      'wallet_id': 1,
      'created_at': DateTime(2026, 8).toIso8601String(),
    });
    await db.insert('expense_payments', <String, Object?>{
      'expense_id': 1,
      'wallet_id': 1,
      'month_key': '2026-08',
      'amount': 600.0,
      'paid_at': DateTime(2026, 8, 10).toIso8601String(),
    });

    await db.close();
  });

  tearDown(() => directory.delete(recursive: true));

  test('migra o banco da versão 1 preservando o que já estava salvo', () async {
    final database = AppDatabase(
      factory: databaseFactoryFfiNoIsolate,
      filePath: path,
    );
    addTearDown(database.close);

    final changes = DataChanges();
    final wallets = WalletRepository(database, changes);
    final expenses = ExpenseRepository(database, changes);

    final wallet = (await wallets.fetchWallets()).single;
    final receipt = (await wallets.fetchReceipts()).single;

    expect(wallet.name, 'Salário');
    expect(wallet.payouts.single.day, 5);
    expect(wallet.payouts.single.schedule, PayoutSchedule.dayOfMonth);
    expect(receipt.status, ReceiptStatus.confirmed);
    expect(receipt.kind, ReceiptKind.income);
    expect((await expenses.fetchExpenses()).single.name, 'Mercado');
    expect((await expenses.fetchPayments()).single.amount, 600);
    expect(await expenses.fetchMonthAmounts(), isEmpty);
  });

  test('o banco migrado aceita um ajuste de saldo', () async {
    final database = AppDatabase(
      factory: databaseFactoryFfiNoIsolate,
      filePath: path,
    );
    addTearDown(database.close);

    final repository = WalletRepository(database, DataChanges());
    final wallet = (await repository.fetchWallets()).single;

    await repository.adjustBalance(
      wallet: wallet,
      currentBalance: 3000,
      targetBalance: 5000,
    );

    final adjustment = (await repository.fetchReceipts())
        .where((receipt) => receipt.isAdjustment)
        .single;

    expect(adjustment.amount, 2000);
  });

  test('o banco migrado aceita dois pagamentos no mesmo mês', () async {
    final database = AppDatabase(
      factory: databaseFactoryFfiNoIsolate,
      filePath: path,
    );
    addTearDown(database.close);

    final repository = ExpenseRepository(database, DataChanges());
    await repository.savePayment(
      ExpensePayment(
        expenseId: 1,
        walletId: 1,
        month: const Month(2026, 8),
        amount: 150,
        paidAt: DateTime(2026, 8, 11),
      ),
    );

    expect(await repository.fetchPayments(), hasLength(2));
  });
}
