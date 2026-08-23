import 'package:flutter/foundation.dart';

import '../state/data_changes.dart';

abstract class ReactiveViewModel extends ChangeNotifier {
  ReactiveViewModel(this._changes) {
    _changes.addListener(refresh);
  }

  final DataChanges _changes;

  bool _isLoading = true;
  bool _isDisposed = false;

  bool get isLoading => _isLoading;

  @protected
  Future<void> loadData();

  Future<void> initialize() async {
    _isLoading = true;
    await refresh();
  }

  Future<void> refresh() async {
    await loadData();
    _isLoading = false;
    safeNotify();
  }

  @protected
  void safeNotify() {
    if (_isDisposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _changes.removeListener(refresh);
    super.dispose();
  }
}
