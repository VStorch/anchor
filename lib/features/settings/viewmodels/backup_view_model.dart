import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/database/database_backup.dart';
import '../../../core/state/data_changes.dart';
import '../services/backup_files.dart';

class BackupViewModel extends ChangeNotifier {
  BackupViewModel({
    required DatabaseBackup backup,
    required BackupFiles files,
    required DataChanges changes,
  }) : _backup = backup,
       _files = files,
       _changes = changes;

  static const String _lastSavedKey = 'backup_last_saved_at';

  final DatabaseBackup _backup;
  final BackupFiles _files;
  final DataChanges _changes;

  DateTime? _lastSavedAt;
  bool _isBusy = false;

  DateTime? get lastSavedAt => _lastSavedAt;
  bool get isBusy => _isBusy;

  Future<void> initialize() async {
    final preferences = await SharedPreferences.getInstance();
    final stored = preferences.getString(_lastSavedKey);
    _lastSavedAt = stored == null ? null : DateTime.tryParse(stored);
    notifyListeners();
  }

  Future<bool> save() => _busy(() async {
    final now = DateTime.now();
    final bytes = await _backup.export();
    final saved = await _files.save(DatabaseBackup.fileNameFor(now), bytes);
    if (!saved) return false;

    _lastSavedAt = now;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_lastSavedKey, now.toIso8601String());
    return true;
  });

  Future<BackupContents?> pick() => _busy(() async {
    final bytes = await _files.open();
    return bytes == null ? null : _backup.inspect(bytes);
  });

  Future<void> restore(BackupContents contents) => _busy(() async {
    await _backup.restore(contents.bytes);
    _changes.publish();
  });

  Future<T> _busy<T>(Future<T> Function() action) async {
    _isBusy = true;
    notifyListeners();
    try {
      return await action();
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }
}
