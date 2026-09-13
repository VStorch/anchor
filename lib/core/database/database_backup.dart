import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart' show OpenDatabaseOptions;

import 'app_database.dart';

enum BackupProblem {
  notABackup('Esse arquivo não é uma cópia do Anchor'),
  newerApp('Essa cópia veio de uma versão mais nova do Anchor');

  const BackupProblem(this.message);

  final String message;
}

class BackupException implements Exception {
  const BackupException(this.problem);

  final BackupProblem problem;

  @override
  String toString() => problem.message;
}

class BackupContents {
  const BackupContents({
    required this.bytes,
    required this.walletCount,
    required this.expenseCount,
  });

  final Uint8List bytes;
  final int walletCount;
  final int expenseCount;
}

/// A backup is the SQLite file itself, so a copy made by an older version goes
/// through the same migrations as the database on the phone. File I/O is sync
/// on purpose: the file is tiny, and async I/O stalls under the test clock.
class DatabaseBackup {
  const DatabaseBackup(this._database);

  static final List<int> _sqliteHeader = ascii.encode('SQLite format 3\u0000');

  final AppDatabase _database;

  static String fileNameFor(DateTime date) =>
      'anchor-${DateFormat('yyyy-MM-dd').format(date)}.db';

  Future<Uint8List> export() =>
      _database.whileClosed((path) async => File(path).readAsBytesSync());

  Future<BackupContents> inspect(Uint8List bytes) async {
    if (!_startsWithSqliteHeader(bytes)) {
      throw const BackupException(BackupProblem.notABackup);
    }

    final candidate = File('${await _database.path}.incoming');
    candidate.writeAsBytesSync(bytes, flush: true);
    try {
      final db = await _database.factory.openDatabase(
        candidate.path,
        options: OpenDatabaseOptions(readOnly: true, singleInstance: false),
      );
      try {
        final version = _firstInt(await db.rawQuery('PRAGMA user_version'));
        if (version > AppDatabase.version) {
          throw const BackupException(BackupProblem.newerApp);
        }
        return BackupContents(
          bytes: bytes,
          walletCount: _firstInt(
            await db.rawQuery(
              'SELECT COUNT(*) FROM ${AppDatabase.walletsTable}',
            ),
          ),
          expenseCount: _firstInt(
            await db.rawQuery(
              'SELECT COUNT(*) FROM ${AppDatabase.expensesTable}',
            ),
          ),
        );
      } finally {
        await db.close();
      }
    } on BackupException {
      rethrow;
    } catch (_) {
      throw const BackupException(BackupProblem.notABackup);
    } finally {
      _deleteIfPresent(candidate);
    }
  }

  Future<void> restore(Uint8List bytes) async {
    await inspect(bytes);

    final previous = await _database.whileClosed((path) async {
      final previous = File('$path.previous');
      final current = File(path);
      if (current.existsSync()) current.renameSync(previous.path);
      _deleteSidecars(path);
      File(path).writeAsBytesSync(bytes, flush: true);
      return previous;
    });

    try {
      await _database.database;
    } catch (_) {
      await _database.whileClosed((path) async {
        _deleteIfPresent(File(path));
        _deleteSidecars(path);
        if (previous.existsSync()) previous.renameSync(path);
      });
      rethrow;
    }
    _deleteIfPresent(previous);
  }

  static bool _startsWithSqliteHeader(Uint8List bytes) {
    if (bytes.length < _sqliteHeader.length) return false;
    for (var i = 0; i < _sqliteHeader.length; i++) {
      if (bytes[i] != _sqliteHeader[i]) return false;
    }
    return true;
  }

  static int _firstInt(List<Map<String, Object?>> rows) =>
      (rows.first.values.first as num?)?.toInt() ?? 0;

  static void _deleteSidecars(String path) {
    for (final suffix in const ['-journal', '-wal', '-shm']) {
      _deleteIfPresent(File('$path$suffix'));
    }
  }

  static void _deleteIfPresent(File file) {
    if (file.existsSync()) file.deleteSync();
  }
}
