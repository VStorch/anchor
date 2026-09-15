import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsViewModel extends ChangeNotifier {
  static const String _themeModeKey = 'theme_mode';
  static const String _onboardingDoneKey = 'onboarding_done';

  ThemeMode _themeMode = ThemeMode.system;
  bool _onboardingDone = false;

  ThemeMode get themeMode => _themeMode;

  bool get onboardingDone => _onboardingDone;

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
}
