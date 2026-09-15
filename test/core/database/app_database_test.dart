import 'dart:io';

import 'package:anchor/core/database/app_database.dart';
import 'package:anchor/core/database/database_backup.dart';
import 'package:anchor/core/state/data_changes.dart';
import 'package:anchor/core/utils/month.dart';
import 'package:anchor/features/budget/models/wallet_summary.dart';
import 'package:anchor/features/budget/services/budget_service.dart';
import 'package:anchor/features/cards/models/credit_card.dart';
import 'package:anchor/features/cards/repositories/card_repository.dart';
import 'package:anchor/features/expenses/models/expense_payment.dart';
import 'package:anchor/features/expenses/repositories/expense_repository.dart';
import 'package:anchor/features/wallets/models/outflow.dart';
import 'package:anchor/features/wallets/models/payout_schedule.dart';
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
    await db.insert('expense_payments', <String, Object?>{
      'expense_id': 1,
      'wallet_id': null,
      'month_key': '2026-07',
      'amount': 50.0,
      'paid_at': DateTime(2026, 7, 10).toIso8601String(),
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
    expect((await expenses.fetchExpenses()).single.name, 'Mercado');
    expect(
      (await expenses.fetchPayments()).map((payment) => payment.amount),
      containsAll(<double>[600, 50]),
    );
    expect(await expenses.fetchMonthAmounts(), isEmpty);
  });

  group('ajustes de saldo antigos', () {
    Future<void> seedAdjustmentsAtVersion7() async {
      final v7 = AppDatabase(
        factory: databaseFactoryFfiNoIsolate,
        filePath: path,
        schemaVersion: 7,
      );
      final db = await v7.database;

      await db.insert('receipts', <String, Object?>{
        'wallet_id': 1,
        'payout_id': 1,
        'month_key': '2026-09',
        'amount': 3200.0,
        'received_at': DateTime(2026, 9, 8).toIso8601String(),
        'status': 'predicted',
      });
      await db.insert('receipts', <String, Object?>{
        'wallet_id': 1,
        'month_key': '2026-09',
        'amount': 500.0,
        'received_at': DateTime(2026, 9, 1).toIso8601String(),
        'status': 'skipped',
      });
      await db.insert('outflows', <String, Object?>{
        'wallet_id': 1,
        'month_key': '2026-09',
        'description': 'Mercado',
        'amount': 100.0,
        'spent_at': DateTime(2026, 9, 9).toIso8601String(),
      });
      await db.insert('receipts', <String, Object?>{
        'wallet_id': 1,
        'month_key': '2026-09',
        'amount': -4600.0,
        'received_at': DateTime(2026, 9, 13, 10).toIso8601String(),
        'kind': 'adjustment',
      });
      await db.insert('expense_payments', <String, Object?>{
        'expense_id': 1,
        'wallet_id': 1,
        'month_key': '2026-09',
        'amount': 100.0,
        'paid_at': DateTime(2026, 9, 14).toIso8601String(),
      });
      await db.insert('receipts', <String, Object?>{
        'wallet_id': 1,
        'month_key': '2026-09',
        'amount': 250.0,
        'received_at': DateTime(2026, 9, 20).toIso8601String(),
        'kind': 'adjustment',
      });

      await v7.close();
    }

    Future<void> expectChecksReplaceAdjustments(AppDatabase database) async {
      final changes = DataChanges();
      final wallets = WalletRepository(database, changes);
      final checks = await wallets.fetchBalanceChecks();
      final receipts = await wallets.fetchReceipts();

      expect(checks.map((check) => check.amount), [850, 1000]);
      expect(checks.map((check) => check.checkedAt), [
        DateTime(2026, 9, 13, 10),
        DateTime(2026, 9, 20),
      ]);
      expect(receipts.map((receipt) => receipt.amount), [3200, 500, 3000]);
      expect(receipts.first.status, ReceiptStatus.predicted);

      final summary = WalletSummary.buildAll(
        month: const Month(2026, 9),
        wallets: await wallets.fetchWallets(),
        receipts: receipts,
        payments: await ExpenseRepository(database, changes).fetchPayments(),
        occurrences: const [],
        checks: checks,
        outflows: await wallets.fetchOutflows(),
      ).single;
      expect(summary.balance, 1000);
    }

    test('viram saldos informados com o valor que a pessoa via', () async {
      await seedAdjustmentsAtVersion7();
      final database = AppDatabase(
        factory: databaseFactoryFfiNoIsolate,
        filePath: path,
      );
      addTearDown(database.close);

      await expectChecksReplaceAdjustments(database);
    });

    test('uma cópia com ajuste é restaurada com o saldo informado', () async {
      await seedAdjustmentsAtVersion7();
      final database = AppDatabase(
        factory: databaseFactoryFfiNoIsolate,
        filePath: '${directory.path}/current.db',
      );
      addTearDown(database.close);

      await DatabaseBackup(database).restore(File(path).readAsBytesSync());

      await expectChecksReplaceAdjustments(database);
    });
  });

  test('a migração dá carteira ao pagamento que não tinha', () async {
    final database = AppDatabase(
      factory: databaseFactoryFfiNoIsolate,
      filePath: path,
    );
    addTearDown(database.close);

    final payments = await ExpenseRepository(
      database,
      DataChanges(),
    ).fetchPayments();

    expect(payments, hasLength(2));
    expect(payments.every((payment) => payment.walletId == 1), isTrue);
  });

  test('o banco migrado aceita um gasto avulso', () async {
    final database = AppDatabase(
      factory: databaseFactoryFfiNoIsolate,
      filePath: path,
    );
    addTearDown(database.close);

    final repository = WalletRepository(database, DataChanges());
    final wallet = (await repository.fetchWallets()).single;

    await repository.saveOutflow(
      Outflow(
        walletId: wallet.id!,
        description: 'Mercado',
        amount: 47.90,
        spentAt: DateTime(2026, 8, 12),
      ),
    );

    expect((await repository.fetchOutflows()).single.amount, 47.90);
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

    expect(await repository.fetchPayments(), hasLength(3));
  });

  test('uma cópia salva na versão 1 é restaurada já migrada', () async {
    final database = AppDatabase(
      factory: databaseFactoryFfiNoIsolate,
      filePath: '${directory.path}/current.db',
    );
    addTearDown(database.close);

    await DatabaseBackup(database).restore(File(path).readAsBytesSync());

    final changes = DataChanges();
    final wallet = (await WalletRepository(
      database,
      changes,
    ).fetchWallets()).single;
    final payments = await ExpenseRepository(database, changes).fetchPayments();

    expect(wallet.name, 'Salário');
    expect(payments.every((payment) => payment.walletId == 1), isTrue);
  });

  test('o banco migrado aceita um cartão com compras', () async {
    final database = AppDatabase(
      factory: databaseFactoryFfiNoIsolate,
      filePath: path,
    );
    addTearDown(database.close);

    final changes = DataChanges();
    final cardId = await CardRepository(database, changes).saveCard(
      CreditCard(
        name: 'Nubank',
        closingDay: 3,
        dueDay: 10,
        walletId: 1,
        createdAt: DateTime(2026, 9),
      ),
    );
    final expenses = ExpenseRepository(database, changes);
    final market = (await expenses.fetchExpenses()).single;
    await expenses.saveExpense(market.copyWith(cardId: cardId));

    expect((await expenses.fetchExpenses()).single.cardId, cardId);
  });

  test('a migração dá ao recebimento a data de criação da carteira', () async {
    final database = AppDatabase(
      factory: databaseFactoryFfiNoIsolate,
      filePath: path,
    );
    addTearDown(database.close);

    final repository = WalletRepository(database, DataChanges());
    final wallet = (await repository.fetchWallets()).single;

    expect(wallet.payouts.single.createdAt, DateTime(2026, 8));
    expect(wallet.payouts.single.startMonth, const Month(2026, 8));
  });

  test(
    'a migração marca o pagamento sem carteira como outro dinheiro',
    () async {
      final v8 = AppDatabase(
        factory: databaseFactoryFfiNoIsolate,
        filePath: path,
        schemaVersion: 8,
      );
      await (await v8.database).insert('expense_payments', <String, Object?>{
        'expense_id': 1,
        'wallet_id': null,
        'month_key': '2026-09',
        'amount': 80.0,
        'paid_at': DateTime(2026, 9, 10).toIso8601String(),
      });
      await v8.close();

      final database = AppDatabase(
        factory: databaseFactoryFfiNoIsolate,
        filePath: path,
      );
      addTearDown(database.close);

      final payments = await ExpenseRepository(
        database,
        DataChanges(),
      ).fetchPayments();

      final outside = payments.where((payment) => payment.walletId == null);
      expect(outside.single.amount, 80);
      expect(outside.single.settledOutside, isTrue);
      expect(
        payments
            .where((payment) => payment.walletId != null)
            .every((payment) => !payment.settledOutside),
        isTrue,
      );
    },
  );

  test(
    'a migração mantém a compra de cartão antiga sem data e aceita a data',
    () async {
      final v9 = AppDatabase(
        factory: databaseFactoryFfiNoIsolate,
        filePath: path,
        schemaVersion: 9,
      );
      final cardId = await CardRepository(v9, DataChanges()).saveCard(
        CreditCard(
          name: 'Nubank',
          closingDay: 3,
          dueDay: 10,
          walletId: 1,
          createdAt: DateTime(2026, 9),
        ),
      );
      await (await v9.database).update('expenses', <String, Object?>{
        'card_id': cardId,
      });
      await v9.close();

      final database = AppDatabase(
        factory: databaseFactoryFfiNoIsolate,
        filePath: path,
      );
      addTearDown(database.close);

      final expenses = ExpenseRepository(database, DataChanges());
      final legacy = (await expenses.fetchExpenses()).single;
      expect(legacy.cardId, cardId);
      expect(legacy.purchasedAt, isNull);
      expect(legacy.startMonth, const Month(2026, 8));

      await expenses.saveExpense(
        legacy.copyWith(purchasedAt: DateTime(2026, 9, 13)),
      );
      expect(
        (await expenses.fetchExpenses()).single.purchasedAt,
        DateTime(2026, 9, 13),
      );
    },
  );

  test('a migração dá ao recebimento a marca de saldo vazia', () async {
    final v10 = AppDatabase(
      factory: databaseFactoryFfiNoIsolate,
      filePath: path,
      schemaVersion: 10,
    );
    await (await v10.database).insert('balance_checks', <String, Object?>{
      'wallet_id': 1,
      'amount': 850.0,
      'checked_at': DateTime(2026, 9, 14, 13).toIso8601String(),
    });
    await v10.close();

    final database = AppDatabase(
      factory: databaseFactoryFfiNoIsolate,
      filePath: path,
    );
    addTearDown(database.close);

    final repository = WalletRepository(database, DataChanges());
    final receipt = (await repository.fetchReceipts()).single;
    expect(receipt.pendingAtCheckId, isNull);

    final check = (await repository.fetchBalanceChecks()).single;
    await repository.saveBalanceCheck(check, leftPending: [receipt]);
    expect(
      (await repository.fetchReceipts()).single.pendingAtCheckId,
      check.id,
    );
  });

  test('os salários previstos antigos voltam ao saldo e ao Entrou depois da '
      'atualização', () async {
    final v7 = AppDatabase(
      factory: databaseFactoryFfiNoIsolate,
      filePath: path,
      schemaVersion: 7,
    );
    final v7Db = await v7.database;
    for (final month in ['2026-06', '2026-07']) {
      await v7Db.insert('receipts', <String, Object?>{
        'wallet_id': 1,
        'payout_id': 1,
        'month_key': month,
        'amount': 3000.0,
        'received_at': DateTime.parse('$month-05').toIso8601String(),
        'status': 'predicted',
      });
    }
    final v7Balance =
        (await v7Db.rawQuery(
              "SELECT (SELECT SUM(amount) FROM receipts WHERE wallet_id = 1 "
              "AND status != 'skipped') - (SELECT SUM(amount) FROM "
              'expense_payments WHERE wallet_id = 1) AS balance',
            )).single['balance']!
            as double;
    await v7.close();

    final database = AppDatabase(
      factory: databaseFactoryFfiNoIsolate,
      filePath: path,
    );
    addTearDown(database.close);
    final changes = DataChanges();
    final service = BudgetService(
      ExpenseRepository(database, changes),
      WalletRepository(database, changes),
      CardRepository(database, changes),
    );

    final july = await service.loadSnapshot(
      const Month(2026, 7),
      now: DateTime(2026, 9, 14, 10),
    );

    expect(july.summaryFor(1)!.balance, v7Balance);
    expect(july.summaryFor(1)!.receivedInMonth, 3000);
  });

  test('o banco migrado tem o mesmo esquema de uma instalação nova', () async {
    final migrated = AppDatabase(
      factory: databaseFactoryFfiNoIsolate,
      filePath: path,
    );
    final fresh = AppDatabase(
      factory: databaseFactoryFfiNoIsolate,
      filePath: '${directory.path}/fresh.db',
    );
    addTearDown(migrated.close);
    addTearDown(fresh.close);

    expect(
      await _describeSchema(await migrated.database),
      await _describeSchema(await fresh.database),
    );
  });
}

Future<Map<String, Object?>> _describeSchema(Database db) async {
  final tables = await db.rawQuery(
    "SELECT name FROM sqlite_master WHERE type = 'table' "
    "AND name NOT LIKE 'sqlite_%' AND name != 'android_metadata' "
    'ORDER BY name',
  );

  return <String, Object?>{
    'user_version': await db.getVersion(),
    for (final table in tables.map((row) => row['name']! as String))
      table: <String, Object?>{
        'columns': await db.rawQuery('PRAGMA table_info($table)'),
        'foreign_keys': await db.rawQuery('PRAGMA foreign_key_list($table)'),
        'indexes': await _describeIndexes(db, table),
      },
  };
}

Future<Map<String, Object?>> _describeIndexes(Database db, String table) async {
  final indexes = await db.rawQuery('PRAGMA index_list($table)');

  return <String, Object?>{
    for (final index in indexes)
      index['name']! as String: <String, Object?>{
        'unique': index['unique'],
        'origin': index['origin'],
        'partial': index['partial'],
        'columns': await db.rawQuery('PRAGMA index_info(${index['name']})'),
      },
  };
}
