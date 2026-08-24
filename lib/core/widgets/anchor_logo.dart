import 'package:flutter/material.dart';

class AnchorLogo extends StatelessWidget {
  const AnchorLogo({super.key, this.size = 64, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/logo/anchor_mark.png',
      width: size,
      height: size,
      color: color ?? Theme.of(context).colorScheme.primary,
    );
  }
}
