import 'package:flutter/foundation.dart';

import '../utils/month.dart';

class MonthSelection extends ChangeNotifier {
  Month _current = Month.current();

  Month get current => _current;

  bool get isCurrentMonth => _current.isCurrent;

  set current(Month month) {
    if (_current == month) return;
    _current = month;
    notifyListeners();
  }

  void goToPrevious() => current = _current.previous;

  void goToNext() => current = _current.next;

  void goToToday() => current = Month.current();
}
