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

  void _unfocus() => FocusManager.instance.primaryFocus?.unfocus();
}
