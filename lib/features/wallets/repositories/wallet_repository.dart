import 'package:sqflite/sqflite.dart';

import '../../../core/database/app_database.dart';
import '../../../core/state/data_changes.dart';
import '../../../core/utils/month.dart';
import '../models/payout.dart';
import '../models/receipt.dart';
import '../models/wallet.dart';

class WalletRepository {
  WalletRepository(this._database, this._changes);

  final AppDatabase _database;
  final DataChanges _changes;

  Future<List<Wallet>> fetchWallets() async {
    final db = await _database.database;
    final walletRows = await db.query(
      AppDatabase.walletsTable,
      orderBy: 'kind DESC, id ASC',
    );
    final payoutRows = await db.query(
      AppDatabase.payoutsTable,
      orderBy: 'day_of_month ASC',
    );

    final payoutsByWallet = <int, List<Payout>>{};
    for (final row in payoutRows) {
      final payout = Payout.fromMap(row);
      payoutsByWallet
          .putIfAbsent(payout.walletId, () => <Payout>[])
          .add(payout);
    }

    return walletRows
        .map(
          (row) => Wallet.fromMap(
            row,
            payouts: payoutsByWallet[row['id'] as int] ?? const <Payout>[],
          ),
        )
        .toList();
  }

  Future<int> saveWallet(Wallet wallet) async {
    final db = await _database.database;
    final id = await db.insert(
      AppDatabase.walletsTable,
      wallet.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _changes.publish();
    return wallet.id ?? id;
  }

  Future<void> deleteWallet(int id) async {
    final db = await _database.database;
    await db.delete(AppDatabase.walletsTable, where: 'id = ?', whereArgs: [id]);
    _changes.publish();
  }

  Future<void> savePayout(Payout payout) async {
    final db = await _database.database;
    await db.insert(
      AppDatabase.payoutsTable,
      payout.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _changes.publish();
  }

  Future<void> deletePayout(int id) async {
    final db = await _database.database;
    await db.delete(AppDatabase.payoutsTable, where: 'id = ?', whereArgs: [id]);
    await db.delete(
      AppDatabase.receiptsTable,
      where: 'payout_id = ?',
      whereArgs: [id],
    );
    _changes.publish();
  }

  Future<List<Receipt>> fetchReceipts() async {
    final db = await _database.database;
    final rows = await db.query(
      AppDatabase.receiptsTable,
      orderBy: 'received_at DESC',
    );
    return rows.map(Receipt.fromMap).toList();
  }

  Future<void> saveReceipt(Receipt receipt) async {
    final db = await _database.database;
    await db.insert(
      AppDatabase.receiptsTable,
      receipt.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _changes.publish();
  }

  Future<void> deleteReceipt(int id) async {
    final db = await _database.database;
    await db.delete(
      AppDatabase.receiptsTable,
      where: 'id = ?',
      whereArgs: [id],
    );
    _changes.publish();
  }

  Future<int> registerDuePayouts(List<Wallet> wallets) async {
    final db = await _database.database;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final currentMonth = Month.current();
    var created = 0;

    for (final wallet in wallets) {
      if (!wallet.hasSchedule) continue;

      for (
        var month = Month.fromDate(wallet.createdAt);
        month <= currentMonth;
        month = month.next
      ) {
        for (final payout in wallet.payouts) {
          if (payout.id == null) continue;

          final payoutDate = month.dayOf(payout.dayOfMonth);
          if (payoutDate.isAfter(today)) continue;

          final insertedId = await db.insert(
            AppDatabase.receiptsTable,
            Receipt(
              walletId: wallet.id!,
              payoutId: payout.id,
              month: month,
              amount: payout.amount,
              receivedAt: payoutDate,
            ).toMap(),
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
          if (insertedId != 0) created++;
        }
      }
    }

    if (created > 0) _changes.publish();
    return created;
  }
}
