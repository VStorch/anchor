import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/state/data_changes.dart';
import '../../../core/utils/month.dart';
import '../../budget/services/budget_service.dart';
import '../models/due_reminder.dart';
import '../services/reminder_notifications.dart';

class RemindersViewModel extends ChangeNotifier {
  RemindersViewModel({
    required BudgetService budgetService,
    required ReminderNotifications notifications,
    required DataChanges changes,
    DateTime Function() clock = DateTime.now,
  }) : _budgetService = budgetService,
       _notifications = notifications,
       _changes = changes,
       _clock = clock {
    _changes.addListener(_reschedule);
  }

  static const String _enabledKey = 'reminders_enabled';
  static const String _permissionAskedKey = 'reminders_permission_asked';

  final BudgetService _budgetService;
  final ReminderNotifications _notifications;
  final DataChanges _changes;
  final DateTime Function() _clock;

  bool _isEnabled = true;
  Future<void> _queue = Future<void>.value();

  bool get isEnabled => _isEnabled;

  @visibleForTesting
  Future<void> get idle => _queue;

  Future<void> initialize() async {
    final preferences = await SharedPreferences.getInstance();
    _isEnabled = preferences.getBool(_enabledKey) ?? true;
    notifyListeners();
    await _reschedule();
  }

  /// Returns false when the user wanted reminders but Android refused them.
  Future<bool> setEnabled(bool value) async {
    final granted = !value || await _requestPermission();
    await _store(value && granted);
    await _reschedule();
    return granted;
  }

  Future<void> _reschedule() =>
      _queue = _queue.catchError((Object _) {}).then((_) => _rescheduleNow());

  Future<void> _rescheduleNow() async {
    final now = _clock();
    final reminders = _isEnabled ? await _plan(now) : const <DueReminder>[];

    if (reminders.isNotEmpty && !await _grantedOnFirstNeed()) {
      await _store(false);
      await _notifications.replaceAll(const <DueReminder>[]);
      return;
    }
    await _notifications.replaceAll(reminders);
  }

  Future<List<DueReminder>> _plan(DateTime now) async {
    final month = Month.fromDate(now);
    final current = await _budgetService.loadSnapshot(month);
    final next = await _budgetService.loadSnapshot(month.next);

    return DueReminder.plan([
      ...current.summary.payables,
      ...next.summary.payables,
    ], now: now);
  }

  /// The first bill worth a reminder is when Android gets asked. After that
  /// the switch in Ajustes is the user's say, so it never asks again on its own.
  Future<bool> _grantedOnFirstNeed() async {
    final preferences = await SharedPreferences.getInstance();
    if (preferences.getBool(_permissionAskedKey) ?? false) return true;
    return _requestPermission();
  }

  Future<bool> _requestPermission() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_permissionAskedKey, true);
    return _notifications.requestPermission();
  }

  Future<void> _store(bool value) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_enabledKey, value);
    if (_isEnabled == value) return;
    _isEnabled = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _changes.removeListener(_reschedule);
    super.dispose();
  }
}
