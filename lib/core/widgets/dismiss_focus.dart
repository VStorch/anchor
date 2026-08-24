import 'package:flutter/material.dart';

/// No Android o campo de texto continua focado quando se toca fora dele.
class DismissFocusOnTap extends StatelessWidget {
  const DismissFocusOnTap({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      excludeFromSemantics: true,
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: child,
    );
  }
}
