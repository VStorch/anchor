import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_tip.dart';

class SettingsViewModel extends ChangeNotifier {
  static const String _themeModeKey = 'theme_mode';
  static const String _onboardingDoneKey = 'onboarding_done';
  static const String _seenTipsKey = 'seen_tips';

  ThemeMode _themeMode = ThemeMode.system;
  bool _onboardingDone = false;
  Set<String> _seenTips = <String>{};

  ThemeMode get themeMode => _themeMode;

  bool get onboardingDone => _onboardingDone;

  /// Tips wait for the first run to end, and each shows until dismissed.
  bool showsTip(AppTip tip) => _onboardingDone && !_seenTips.contains(tip.id);

  String get themeModeLabel => switch (_themeMode) {
    ThemeMode.system => 'Padrão do sistema',
    ThemeMode.light => 'Claro',
    ThemeMode.dark => 'Escuro',
  };

  Future<void> initialize() async {
    final preferences = await SharedPreferences.getInstance();
    final stored = preferences.getString(_themeModeKey);
    _themeMode = ThemeMode.values.firstWhere(
      (mode) => mode.name == stored,
      orElse: () => ThemeMode.system,
    );
    _onboardingDone = preferences.getBool(_onboardingDoneKey) ?? false;
    _seenTips = (preferences.getStringList(_seenTipsKey) ?? const <String>[])
        .toSet();
    notifyListeners();
  }

  Future<void> markOnboardingDone() async {
    if (_onboardingDone) return;
    _onboardingDone = true;
    notifyListeners();

    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_onboardingDoneKey, true);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();

    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_themeModeKey, mode.name);
  }

  Future<void> dismissTip(AppTip tip) async {
    if (!_seenTips.add(tip.id)) return;
    notifyListeners();

    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(_seenTipsKey, _seenTips.toList());
  }

  /// "Rever dicas": every tab shows its tip again.
  Future<void> resetTips() async {
    _seenTips = <String>{};
    notifyListeners();

    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_seenTipsKey);
  }
}
