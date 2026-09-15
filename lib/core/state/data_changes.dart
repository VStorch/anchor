import 'package:flutter/foundation.dart';

class DataChanges extends ChangeNotifier {
  int _holds = 0;
  bool _pending = false;

  void publish() {
    if (_holds > 0) {
      _pending = true;
      return;
    }
    notifyListeners();
  }

  /// Runs [action] with every [publish] inside it held back, and notifies
  /// once when the outermost hold ends, so a composed write reloads once.
  Future<T> hold<T>(Future<T> Function() action) async {
    _holds++;
    try {
      return await action();
    } finally {
      _holds--;
      if (_holds == 0 && _pending) {
        _pending = false;
        notifyListeners();
      }
    }
  }
}
