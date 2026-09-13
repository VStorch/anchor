import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

abstract interface class BackupFiles {
  Future<bool> save(String fileName, Uint8List bytes);

  Future<Uint8List?> open();
}

class DeviceBackupFiles implements BackupFiles {
  const DeviceBackupFiles();

  @override
  Future<bool> save(String fileName, Uint8List bytes) async =>
      await FilePicker.saveFile(fileName: fileName, bytes: bytes) != null;

  @override
  Future<Uint8List?> open() async {
    final result = await FilePicker.pickFiles(withData: true);
    return result?.files.single.bytes;
  }
}
