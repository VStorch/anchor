import 'package:sqflite/sqflite.dart';

import '../../../core/database/app_database.dart';
import '../../../core/state/data_changes.dart';
import '../../../core/utils/month.dart';
import '../models/balance_check.dart';
import '../models/outflow.dart';
import '../models/payout.dart';
import '../models/receipt.dart';
import '../models/receipt_status.dart';
import '../models/wallet.dart';

class WalletRepository {
  WalletRepository(this._database, this._changes);

  final AppDatabase _database;
  final DataChanges _changes;

  Future<int> _upsert(
    DatabaseExecutor db,
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

  /// The form's save is one user action: the wallet, its payouts and the
  /// removed ones land together, so a reload never sees a payout half-deleted.
  Future<int> saveWalletWithPayouts(
    Wallet wallet, {
    required List<Payout> payouts,
    List<int> removedPayoutIds = const <int>[],
  }) async {
    final db = await _database.database;
    final walletId = await db.transaction((txn) async {
      final walletId = await _upsert(
        txn,
        AppDatabase.walletsTable,
        wallet.toMap(),
        wallet.id,
      );
      for (final payoutId in removedPayoutIds) {
        await _deletePayout(txn, payoutId);
      }
      for (final payout in payouts) {
        await _upsert(
          txn,
          AppDatabase.payoutsTable,
          payout.copyWith(walletId: walletId).toMap(),
          payout.id,
        );
      }
      return walletId;
    });
    _changes.publish();
    return walletId;
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
    await db.transaction((txn) => _deletePayout(txn, id));
    _changes.publish();
  }

  Future<void> _deletePayout(DatabaseExecutor db, int id) async {
    await db.delete(
      AppDatabase.receiptsTable,
      where: 'payout_id = ? AND status = ?',
      whereArgs: [id, ReceiptStatus.predicted.id],
    );
    await db.delete(AppDatabase.payoutsTable, where: 'id = ?', whereArgs: [id]);
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

  Future<List<BalanceCheck>> fetchBalanceChecks() async {
    final db = await _database.database;
    final rows = await db.query(
      AppDatabase.balanceChecksTable,
      orderBy: 'checked_at ASC, id ASC',
    );
    return rows.map(BalanceCheck.fromMap).toList();
  }

  /// Saying what a wallet holds often comes with "and the salary did land":
  /// both are written together, so the balance never flickers in between.
  Future<void> saveBalanceCheck(
    BalanceCheck check, {
    List<Receipt> confirm = const <Receipt>[],
  }) async {
    final db = await _database.database;
    await db.transaction((txn) async {
      for (final receipt in confirm) {
        await _upsert(
          txn,
          AppDatabase.receiptsTable,
          receipt.copyWith(status: ReceiptStatus.confirmed).toMap(),
          receipt.id,
        );
      }
      await _upsert(
        txn,
        AppDatabase.balanceChecksTable,
        check.toMap(),
        check.id,
      );
    });
    _changes.publish();
  }

  Future<void> deleteBalanceCheck(int id) async {
    final db = await _database.database;
    await db.delete(
      AppDatabase.balanceChecksTable,
      where: 'id = ?',
      whereArgs: [id],
    );
    _changes.publish();
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

  Future<List<Outflow>> fetchOutflows() async {
    final db = await _database.database;
    final rows = await db.query(
      AppDatabase.outflowsTable,
      orderBy: 'spent_at DESC',
    );
    return rows.map(Outflow.fromMap).toList();
  }

  Future<void> saveOutflow(Outflow outflow) async {
    final db = await _database.database;
    await _upsert(db, AppDatabase.outflowsTable, outflow.toMap(), outflow.id);
    _changes.publish();
  }

  Future<void> deleteOutflow(int id) async {
    final db = await _database.database;
    await db.delete(
      AppDatabase.outflowsTable,
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
    var changed = 0;

    for (final wallet in wallets) {
      final walletStart = Month.fromDate(wallet.createdAt);

      for (final payout in wallet.payouts) {
        if (payout.id == null) continue;

        for (
          var month = payout.startMonth > walletStart
              ? payout.startMonth
              : walletStart;
          month <= currentMonth;
          month = month.next
        ) {
          if (month == currentMonth) {
            changed += await _resyncPredicted(db, payout, month);
          }

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
          if (insertedId != 0) changed++;
        }
      }
    }

    if (changed > 0) _changes.publish();
    return changed;
  }

  /// Editing the payout fixes the month on screen now, but a past month keeps
  /// what it was predicted with, so its balance does not shift behind the user.
  Future<int> _resyncPredicted(Database db, Payout payout, Month month) {
    final payoutDate = payout.dateIn(month).toIso8601String();
    return db.update(
      AppDatabase.receiptsTable,
      <String, Object?>{'amount': payout.amount, 'received_at': payoutDate},
      where:
          'payout_id = ? AND month_key = ? AND status = ? '
          'AND (amount != ? OR received_at != ?)',
      whereArgs: [
        payout.id,
        month.key,
        ReceiptStatus.predicted.id,
        payout.amount,
        payoutDate,
      ],
    );
  }
}
