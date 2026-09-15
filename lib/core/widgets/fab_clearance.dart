import 'package:flutter/widgets.dart';

/// Bottom padding for a list under an extended FloatingActionButton, so its
/// last item can scroll above the button at any font size.
double fabClearance(BuildContext context) =>
    MediaQuery.textScalerOf(context).scale(56) +
    32 +
    MediaQuery.paddingOf(context).bottom;
