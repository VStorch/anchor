import 'package:flutter/foundation.dart';

import '../utils/month.dart';

class MonthSelection extends ChangeNotifier {
  MonthSelection({DateTime Function() clock = DateTime.now})
    : _clock = clock,
      _current = Month.fromDate(clock());

  final DateTime Function() _clock;
  Month _current;

  Month get current => _current;

  bool get isCurrentMonth => _current == Month.fromDate(_clock());

  set current(Month month) {
    if (_current == month) return;
    _current = month;
    notifyListeners();
  }

  void goToPrevious() => current = _current.previous;

  void goToNext() => current = _current.next;

  void goToToday() => current = Month.fromDate(_clock());
}
