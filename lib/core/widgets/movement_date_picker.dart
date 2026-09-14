import 'package:flutter/material.dart';

/// The picker's range is built around the date it opens on, so a month far
/// from today on screen can never fall outside `firstDate`..`lastDate`.
Future<DateTime?> pickMovementDate(BuildContext context, DateTime initial) =>
    showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(initial.year - 5),
      lastDate: DateTime(initial.year + 5, 12, 31),
    );
