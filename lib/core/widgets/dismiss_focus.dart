import 'package:flutter/material.dart';

/// No Android o campo de texto continua focado ao tocar fora dele ou ao rolar
/// a tela. A rolagem programática — a que traz o campo focado para cima do
/// teclado — não tem `dragDetails` e por isso não mexe no foco.
class DismissFocus extends StatelessWidget {
  const DismissFocus({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollStartNotification>(
      onNotification: (notification) {
        if (notification.dragDetails != null) _unfocus();
        return false;
      },
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        excludeFromSemantics: true,
        onTap: _unfocus,
        child: child,
      ),
    );
  }

  void _unfocus() => releaseFocus();
}

/// A route that closes gives the focus back to the field focused when it
/// opened, and the keyboard pops up again over the answer just picked. Every
/// day, date or month picker calls this before opening.
void releaseFocus() => FocusManager.instance.primaryFocus?.unfocus();
