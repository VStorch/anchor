import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../viewmodels/reminders_view_model.dart';

/// Asks Android again whether notifications can show every time the app
/// comes back to the foreground, so the "desligadas" notice goes away as soon
/// as the user turns them on in the system settings.
class RemindersResumeWatcher extends StatefulWidget {
  const RemindersResumeWatcher({super.key, required this.child});

  final Widget child;

  @override
  State<RemindersResumeWatcher> createState() => _RemindersResumeWatcherState();
}

class _RemindersResumeWatcherState extends State<RemindersResumeWatcher> {
  late final AppLifecycleListener _listener = AppLifecycleListener(
    onResume: () => context.read<RemindersViewModel>().recheckSystem(),
  );

  @override
  void initState() {
    super.initState();
    _listener;
  }

  @override
  void dispose() {
    _listener.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
