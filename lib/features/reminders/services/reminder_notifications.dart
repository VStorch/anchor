import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../models/due_reminder.dart';

abstract interface class ReminderNotifications {
  Future<bool> requestPermission();

  Future<void> replaceAll(List<DueReminder> reminders);
}

class LocalReminderNotifications implements ReminderNotifications {
  LocalReminderNotifications();

  static const AndroidNotificationDetails _channel = AndroidNotificationDetails(
    'due_reminders',
    'Vencimentos',
    channelDescription: 'Aviso no dia em que uma conta vence',
  );

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  Future<bool?>? _initialized;

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  @override
  Future<bool> requestPermission() async {
    await _initialize();
    return await _android?.requestNotificationsPermission() ?? false;
  }

  @override
  Future<void> replaceAll(List<DueReminder> reminders) async {
    await _initialize();
    await _plugin.cancelAll();
    for (final reminder in reminders) {
      await _plugin.zonedSchedule(
        id: reminder.id,
        title: reminder.title,
        body: reminder.body,
        scheduledDate: tz.TZDateTime.from(reminder.at, tz.UTC),
        notificationDetails: const NotificationDetails(android: _channel),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }

  Future<bool?> _initialize() => _initialized ??= _plugin.initialize(
    settings: const InitializationSettings(
      android: AndroidInitializationSettings('ic_logo_mark'),
    ),
  );
}
