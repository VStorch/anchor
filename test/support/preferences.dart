import 'package:shared_preferences/shared_preferences.dart';

/// Preferences of someone past the first-run setup, so widget tests open
/// straight on the tabs.
void mockPreferences([Map<String, Object> values = const <String, Object>{}]) {
  SharedPreferences.setMockInitialValues(<String, Object>{
    'onboarding_done': true,
    ...values,
  });
}
