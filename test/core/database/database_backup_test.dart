import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:anchor/core/database/app_database.dart';
import 'package:anchor/core/database/database_backup.dart';
import 'package:anchor/core/state/data_changes.dart';
import 'package:anchor/features/wallets/models/wallet.dart';
import 'package:anchor/features/wallets/models/wallet_kind.dart';
import 'package:anchor/features/wallets/repositories/wallet_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../support/test_database.dart';

void main() {
  late Directory directory;
  late AppDatabase database;
  late DatabaseBackup backup;
  late WalletRepository wallets;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('anchor_backup');
    database = createFileDatabase('${directory.path}/anchor.db');
    backup = DatabaseBackup(database);
    wallets = WalletRepository(database, DataChanges());
  });

  tearDown(() async {
    await database.close();
    await directory.delete(recursive: true);
  });

  Future<void> createWallet(String name) => wallets.saveWallet(
    Wallet(
      name: name,
      kind: WalletKind.benefit,
      colorIndex: 0,
      createdAt: DateTime(2026, 9),
    ),
  );

  Future<List<String>> walletNames() async =>
      (await wallets.fetchWallets()).map((wallet) => wallet.name).toList();

  test('restaurar a cópia devolve os dados de quando ela foi salva', () async {
    await createWallet('Salário');
    final bytes = await backup.export();

    await createWallet('Vale');
    expect(await walletNames(), ['Salário', 'Vale']);

    await backup.restore(bytes);

    expect(await walletNames(), ['Salário']);
    expect(directory.listSync().map((entry) => entry.uri.pathSegments.last), [
      'anchor.db',
    ]);
  });

  test('conta o que tem na cópia antes de restaurar', () async {
    await createWallet('Salário');
    await createWallet('Vale');

    final contents = await backup.inspect(await backup.export());

    expect(contents.walletCount, 2);
    expect(contents.expenseCount, 0);
  });

  test('recusa um arquivo que não é banco do app', () async {
    await createWallet('Salário');

    for (final bytes in [
      Uint8List.fromList(utf8.encode('nome,valor\nMercado,600')),
      await _emptySqliteFile(directory),
    ]) {
      await expectLater(
        backup.restore(bytes),
        throwsA(
          isA<BackupException>().having(
            (error) => error.problem,
            'problem',
            BackupProblem.notABackup,
          ),
        ),
      );
    }

    expect(await walletNames(), ['Salário']);
  });

  test('recusa a cópia de uma versão mais nova do app', () async {
    await createWallet('Salário');
    final path = '${directory.path}/future.db';
    final future = await databaseFactoryFfiNoIsolate.openDatabase(path);
    await future.execute('CREATE TABLE wallets (id INTEGER PRIMARY KEY)');
    await future.execute('CREATE TABLE expenses (id INTEGER PRIMARY KEY)');
    await future.setVersion(AppDatabase.version + 1);
    await future.close();

    await expectLater(
      backup.restore(File(path).readAsBytesSync()),
      throwsA(
        isA<BackupException>().having(
          (error) => error.problem,
          'problem',
          BackupProblem.newerApp,
        ),
      ),
    );
    expect(await walletNames(), ['Salário']);
  });
}

Future<Uint8List> _emptySqliteFile(Directory directory) async {
  final path = '${directory.path}/other.db';
  final other = await databaseFactoryFfiNoIsolate.openDatabase(path);
  await other.execute('CREATE TABLE notes (id INTEGER PRIMARY KEY)');
  await other.close();
  final bytes = File(path).readAsBytesSync();
  File(path).deleteSync();
  return bytes;
}
