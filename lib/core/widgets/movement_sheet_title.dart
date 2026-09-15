import 'package:flutter/material.dart';

import '../../app/theme/money_colors.dart';
import '../../app/theme/money_icons.dart';

/// The title of a sheet that records money coming in or going out, with the
/// same arrow and colour the movement gets in the lists.
class MovementSheetTitle extends StatelessWidget {
  const MovementSheetTitle(this.title, {super.key, required this.isIncome});

  final String title;
  final bool isIncome;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = MoneyColors.of(context);
    final color = isIncome ? colors.income : colors.spending;

    return Row(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: color.withValues(alpha: 0.14),
          child: Icon(
            isIncome ? MoneyIcons.income : MoneyIcons.spending,
            size: 18,
            color: color,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
