import 'package:flutter/foundation.dart';

class DataChanges extends ChangeNotifier {
  void publish() => notifyListeners();
}
