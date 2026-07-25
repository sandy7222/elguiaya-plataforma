import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tema claro/oscuro de la app (persistido en SharedPreferences).
class ThemeProvider extends ChangeNotifier {
  static const _prefsKey = 'elguia_theme_dark';

  bool _isDark = false;
  bool _loaded = false;

  bool get isDark => _isDark;
  bool get isLoaded => _loaded;
  ThemeMode get themeMode => _isDark ? ThemeMode.dark : ThemeMode.light;

  ThemeProvider() {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isDark = prefs.getBool(_prefsKey) ?? false;
    } catch (_) {
      _isDark = false;
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> toggle() async {
    await setDark(!_isDark);
  }

  Future<void> setDark(bool value) async {
    if (_isDark == value) return;
    _isDark = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsKey, value);
    } catch (_) {}
  }
}
