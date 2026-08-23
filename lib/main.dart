import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app/anchor_app.dart';
import 'features/settings/viewmodels/settings_view_model.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt_BR');

  final settings = SettingsViewModel();
  await settings.initialize();

  runApp(AnchorApp(settings: settings));
}
