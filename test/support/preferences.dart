import 'package:anchor/features/settings/models/app_tip.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Preferences of someone past the first-run setup and every tab's tip, so
/// widget tests open straight on the tabs.
void mockPreferences([Map<String, Object> values = const <String, Object>{}]) {
  SharedPreferences.setMockInitialValues(<String, Object>{
    'onboarding_done': true,
    'seen_tips': [for (final tip in AppTip.values) tip.id],
    ...values,
  });
}
