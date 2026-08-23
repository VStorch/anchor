import 'dart:ffi';
import 'dart:io';

import 'package:anchor/core/database/app_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqlite3/open.dart';

bool _initialized = false;

AppDatabase createInMemoryDatabase() {
  _initializeOnce();
  return AppDatabase(
    factory: databaseFactoryFfiNoIsolate,
    filePath: inMemoryDatabasePath,
  );
}

void _initializeOnce() {
  if (_initialized) return;
  _initialized = true;

  if (Platform.isLinux) {
    open.overrideFor(OperatingSystem.linux, _openLinuxSqlite);
  }
  sqfliteFfiInit();
}

DynamicLibrary _openLinuxSqlite() {
  for (final name in const ['libsqlite3.so', 'libsqlite3.so.0']) {
    try {
      return DynamicLibrary.open(name);
    } on ArgumentError {
      continue;
    }
  }
  throw StateError('libsqlite3 não encontrada nesta máquina');
}
