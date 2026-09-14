import 'dart:async';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite/sqflite.dart'
    show Database, DatabaseFactory, OpenDatabaseOptions;

class AppDatabase {
  AppDatabase({DatabaseFactory? factory, String? filePath})
    : _factory = factory ?? sqflite.databaseFactory,
      _filePath = filePath;

  static final AppDatabase instance = AppDatabase();

  static const int version = 7;

  static const String walletsTable = 'wallets';
  static const String payoutsTable = 'payouts';
  static const String receiptsTable = 'receipts';
  static const String expensesTable = 'expenses';
  static const String expensePaymentsTable = 'expense_payments';
  static const String expenseMonthsTable = 'expense_months';
  static const String outflowsTable = 'outflows';
  static const String cardsTable = 'cards';

  final DatabaseFactory _factory;
  final String? _filePath;

  Database? _database;
  Completer<void>? _closedFor;

  DatabaseFactory get factory => _factory;

  Future<String> get path async =>
      _filePath ?? p.join(await _factory.getDatabasesPath(), 'anchor.db');

  Future<Database> get database async {
    await _waitUntilOpenable();
    return _database ??= await _open();
  }

  Future<T> whileClosed<T>(Future<T> Function(String path) action) async {
    await _waitUntilOpenable();
    final closedFor = _closedFor = Completer<void>();
    try {
      await close();
      return await action(await path);
    } finally {
      _closedFor = null;
      closedFor.complete();
    }
  }

  Future<void> _waitUntilOpenable() async {
    while (_closedFor != null) {
      await _closedFor!.future;
    }
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }

  Future<Database> _open() async {
    return _factory.openDatabase(
      await path,
      options: OpenDatabaseOptions(
        version: version,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, _) => _run(db, _schema),
        onUpgrade: (db, from, to) async {
          for (var target = from + 1; target <= to; target++) {
            await _run(db, _migrations[target] ?? const <String>[]);
          }
        },
      ),
    );
  }

  static Future<void> _run(Database db, List<String> statements) async {
    final batch = db.batch();
    for (final statement in statements) {
      batch.execute(statement);
    }
    await batch.commit(noResult: true);
  }

  static const List<String> _schema = <String>[
    '''
    CREATE TABLE $walletsTable (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      kind TEXT NOT NULL,
      color_index INTEGER NOT NULL,
      created_at TEXT NOT NULL
    )
    ''',
    '''
    CREATE TABLE $payoutsTable (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      wallet_id INTEGER NOT NULL REFERENCES $walletsTable(id) ON DELETE CASCADE,
      label TEXT NOT NULL,
      amount REAL NOT NULL,
      day_of_month INTEGER NOT NULL,
      schedule_kind TEXT NOT NULL DEFAULT 'day_of_month',
      created_at TEXT NOT NULL DEFAULT ''
    )
    ''',
    '''
    CREATE TABLE $receiptsTable (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      wallet_id INTEGER NOT NULL REFERENCES $walletsTable(id) ON DELETE CASCADE,
      payout_id INTEGER REFERENCES $payoutsTable(id) ON DELETE SET NULL,
      month_key TEXT NOT NULL,
      amount REAL NOT NULL,
      received_at TEXT NOT NULL,
      status TEXT NOT NULL DEFAULT 'confirmed',
      kind TEXT NOT NULL DEFAULT 'income'
    )
    ''',
    'CREATE UNIQUE INDEX idx_receipt_payout_month ON $receiptsTable(payout_id, month_key)',
    '''
    CREATE TABLE $cardsTable (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      closing_day INTEGER NOT NULL,
      due_day INTEGER NOT NULL,
      wallet_id INTEGER REFERENCES $walletsTable(id) ON DELETE SET NULL,
      created_at TEXT NOT NULL
    )
    ''',
    '''
    CREATE TABLE $expensesTable (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      type TEXT NOT NULL,
      amount REAL NOT NULL,
      due_day INTEGER NOT NULL,
      start_month TEXT NOT NULL,
      end_month TEXT,
      total_installments INTEGER,
      settled_installments INTEGER NOT NULL DEFAULT 0,
      wallet_id INTEGER REFERENCES $walletsTable(id) ON DELETE SET NULL,
      created_at TEXT NOT NULL,
      card_id INTEGER REFERENCES $cardsTable(id) ON DELETE SET NULL
    )
    ''',
    '''
    CREATE TABLE $expensePaymentsTable (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      expense_id INTEGER NOT NULL REFERENCES $expensesTable(id) ON DELETE CASCADE,
      wallet_id INTEGER REFERENCES $walletsTable(id) ON DELETE SET NULL,
      month_key TEXT NOT NULL,
      amount REAL NOT NULL,
      paid_at TEXT NOT NULL
    )
    ''',
    'CREATE INDEX idx_payment_expense_month ON $expensePaymentsTable(expense_id, month_key)',
    '''
    CREATE TABLE $expenseMonthsTable (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      expense_id INTEGER NOT NULL REFERENCES $expensesTable(id) ON DELETE CASCADE,
      month_key TEXT NOT NULL,
      amount REAL NOT NULL
    )
    ''',
    'CREATE UNIQUE INDEX idx_expense_month ON $expenseMonthsTable(expense_id, month_key)',
    '''
    CREATE TABLE $outflowsTable (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      wallet_id INTEGER NOT NULL REFERENCES $walletsTable(id) ON DELETE CASCADE,
      month_key TEXT NOT NULL,
      description TEXT NOT NULL,
      amount REAL NOT NULL,
      spent_at TEXT NOT NULL
    )
    ''',
    'CREATE INDEX idx_outflow_wallet_month ON $outflowsTable(wallet_id, month_key)',
  ];

  static const Map<int, List<String>> _migrations = <int, List<String>>{
    2: <String>[
      "ALTER TABLE $payoutsTable ADD COLUMN schedule_kind TEXT NOT NULL DEFAULT 'day_of_month'",
      "ALTER TABLE $receiptsTable ADD COLUMN status TEXT NOT NULL DEFAULT 'confirmed'",
      'DROP INDEX idx_payment_expense_month',
      'CREATE INDEX idx_payment_expense_month ON $expensePaymentsTable(expense_id, month_key)',
      '''
      CREATE TABLE $expenseMonthsTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        expense_id INTEGER NOT NULL REFERENCES $expensesTable(id) ON DELETE CASCADE,
        month_key TEXT NOT NULL,
        amount REAL NOT NULL
      )
      ''',
      'CREATE UNIQUE INDEX idx_expense_month ON $expenseMonthsTable(expense_id, month_key)',
    ],
    3: <String>[
      "ALTER TABLE $receiptsTable ADD COLUMN kind TEXT NOT NULL DEFAULT 'income'",
    ],
    4: <String>[
      '''
      CREATE TABLE $outflowsTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        wallet_id INTEGER NOT NULL REFERENCES $walletsTable(id) ON DELETE CASCADE,
        month_key TEXT NOT NULL,
        description TEXT NOT NULL,
        amount REAL NOT NULL,
        spent_at TEXT NOT NULL
      )
      ''',
      'CREATE INDEX idx_outflow_wallet_month ON $outflowsTable(wallet_id, month_key)',
    ],
    5: <String>[
      '''
      UPDATE $expensePaymentsTable
      SET wallet_id = (
        SELECT wallet_id FROM $expensesTable
        WHERE $expensesTable.id = $expensePaymentsTable.expense_id
      )
      WHERE wallet_id IS NULL
      ''',
    ],
    6: <String>[
      '''
      CREATE TABLE $cardsTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        closing_day INTEGER NOT NULL,
        due_day INTEGER NOT NULL,
        wallet_id INTEGER REFERENCES $walletsTable(id) ON DELETE SET NULL,
        created_at TEXT NOT NULL
      )
      ''',
      'ALTER TABLE $expensesTable ADD COLUMN card_id INTEGER REFERENCES $cardsTable(id) ON DELETE SET NULL',
    ],
    7: <String>[
      "ALTER TABLE $payoutsTable ADD COLUMN created_at TEXT NOT NULL DEFAULT ''",
      '''
      UPDATE $payoutsTable
      SET created_at = (
        SELECT created_at FROM $walletsTable
        WHERE $walletsTable.id = $payoutsTable.wallet_id
      )
      ''',
    ],
  };
}
