import 'package:flutter/material.dart';

/// Shown while Android keeps the app's notifications from showing; opening
/// the system settings would need another plugin, so it says where to go.
class NotificationsBlockedNotice extends StatelessWidget {
  const NotificationsBlockedNotice({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.notifications_off_outlined, color: theme.colorScheme.error),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'As notificações do Anchor estão desligadas no Android. Ative em '
            'Ajustes do Android › Apps › Anchor › Notificações.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ),
      ],
    );
  }
}
