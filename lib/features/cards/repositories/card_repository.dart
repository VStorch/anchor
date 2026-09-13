import '../../../core/database/app_database.dart';
import '../../../core/state/data_changes.dart';
import '../models/credit_card.dart';

class CardRepository {
  CardRepository(this._database, this._changes);

  final AppDatabase _database;
  final DataChanges _changes;

  Future<List<CreditCard>> fetchCards() async {
    final db = await _database.database;
    final rows = await db.query(AppDatabase.cardsTable, orderBy: 'name ASC');
    return rows.map(CreditCard.fromMap).toList();
  }

  /// A card's due day and paying wallet are copied onto its expenses, so the
  /// rest of the app keeps reading them from the expense like any other bill.
  Future<int> saveCard(CreditCard card) async {
    final db = await _database.database;
    final id = await db.transaction((txn) async {
      final values = card.toMap();
      final id = card.id == null
          ? await txn.insert(AppDatabase.cardsTable, values)
          : card.id!;
      if (card.id != null) {
        await txn.update(
          AppDatabase.cardsTable,
          values,
          where: 'id = ?',
          whereArgs: [id],
        );
        await txn.update(
          AppDatabase.expensesTable,
          <String, Object?>{'due_day': card.dueDay, 'wallet_id': card.walletId},
          where: 'card_id = ?',
          whereArgs: [id],
        );
      }
      return id;
    });
    _changes.publish();
    return id;
  }

  Future<void> deleteCard(int id) async {
    final db = await _database.database;
    await db.delete(AppDatabase.cardsTable, where: 'id = ?', whereArgs: [id]);
    _changes.publish();
  }
}
