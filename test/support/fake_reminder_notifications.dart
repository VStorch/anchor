import 'package:anchor/features/reminders/models/due_reminder.dart';
import 'package:anchor/features/reminders/services/reminder_notifications.dart';

class FakeReminderNotifications implements ReminderNotifications {
  FakeReminderNotifications({
    this.grantsPermission = true,
    this.systemEnabled = true,
  });

  bool grantsPermission;
  bool systemEnabled;
  int permissionRequests = 0;
  List<DueReminder> scheduled = const <DueReminder>[];

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return grantsPermission;
  }

  @override
  Future<bool> areEnabled() async => systemEnabled;

  @override
  Future<void> replaceAll(List<DueReminder> reminders) async {
    scheduled = reminders;
  }
}
