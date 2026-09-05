import 'package:sqflite/sqflite.dart';

import '../../../core/database/app_database.dart';
import '../../../core/state/data_changes.dart';
import '../../../core/utils/month.dart';
import '../models/payout.dart';
import '../models/receipt.dart';
import '../models/receipt_kind.dart';
import '../models/receipt_status.dart';
import '../models/wallet.dart';

class WalletRepository {
  WalletRepository(this._database, this._changes);

  final AppDatabase _database;
  final DataChanges _changes;

  Future<int> _upsert(
    Database db,
    String table,
    Map<String, Object?> values,
    int? id,
  ) async {
    if (id == null) return db.insert(table, values);
    await db.update(table, values, where: 'id = ?', whereArgs: [id]);
    return id;
  }

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
    final id = await _upsert(
      db,
      AppDatabase.walletsTable,
      wallet.toMap(),
      wallet.id,
    );
    _changes.publish();
    return id;
  }

  Future<void> deleteWallet(int id) async {
    final db = await _database.database;
    await db.delete(AppDatabase.walletsTable, where: 'id = ?', whereArgs: [id]);
    _changes.publish();
  }

  Future<void> savePayout(Payout payout) async {
    final db = await _database.database;
    await _upsert(db, AppDatabase.payoutsTable, payout.toMap(), payout.id);
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
    await _upsert(db, AppDatabase.receiptsTable, receipt.toMap(), receipt.id);
    _changes.publish();
  }

  Future<void> adjustBalance({
    required Wallet wallet,
    required double currentBalance,
    required double targetBalance,
  }) async {
    final difference = targetBalance - currentBalance;
    if (difference.abs() < 0.005) return;

    final now = DateTime.now();
    await saveReceipt(
      Receipt(
        walletId: wallet.id!,
        month: Month.fromDate(now),
        amount: difference,
        receivedAt: now,
        kind: ReceiptKind.adjustment,
      ),
    );
  }

  Future<void> discardReceipt(Receipt receipt) async {
    final db = await _database.database;
    if (receipt.isManual) {
      await db.delete(
        AppDatabase.receiptsTable,
        where: 'id = ?',
        whereArgs: [receipt.id],
      );
    } else {
      await db.update(
        AppDatabase.receiptsTable,
        <String, Object?>{'status': ReceiptStatus.skipped.id},
        where: 'id = ?',
        whereArgs: [receipt.id],
      );
    }
    _changes.publish();
  }

  Future<int> registerDuePayouts(List<Wallet> wallets) async {
    final db = await _database.database;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final currentMonth = Month.current();
    var changed = 0;

    for (final wallet in wallets) {
      if (!wallet.hasSchedule) continue;

      for (
        var month = Month.fromDate(wallet.createdAt);
        month <= currentMonth;
        month = month.next
      ) {
        for (final payout in wallet.payouts) {
          if (payout.id == null) continue;

          final payoutDate = payout.dateIn(month);
          if (payoutDate.isAfter(today)) continue;

          final insertedId = await db.insert(
            AppDatabase.receiptsTable,
            Receipt(
              walletId: wallet.id!,
              payoutId: payout.id,
              month: month,
              amount: payout.amount,
              receivedAt: payoutDate,
              status: ReceiptStatus.predicted,
            ).toMap(),
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
          if (insertedId != 0) {
            changed++;
            continue;
          }

          changed += await db.update(
            AppDatabase.receiptsTable,
            <String, Object?>{
              'amount': payout.amount,
              'received_at': payoutDate.toIso8601String(),
            },
            where:
                'payout_id = ? AND month_key = ? AND status = ? '
                'AND (amount != ? OR received_at != ?)',
            whereArgs: [
              payout.id,
              month.key,
              ReceiptStatus.predicted.id,
              payout.amount,
              payoutDate.toIso8601String(),
            ],
          );
        }
      }
    }

    if (changed > 0) _changes.publish();
    return changed;
  }
}
