import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeNotifier extends Notifier<ThemeMode> {
  static const _key = 'theme_mode';
  late final SharedPreferences _prefs;

  @override
  ThemeMode build() {
    _init();
    return ThemeMode.dark;
  }

  Future<void> _init() async {
    _prefs = await SharedPreferences.getInstance();
    final index = _prefs.getInt(_key);
    if (index != null) {
      state = ThemeMode.values[index];
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    await _prefs.setInt(_key, mode.index);
  }

  void toggleTheme() {
    if (state == ThemeMode.dark) {
      setThemeMode(ThemeMode.light);
    } else {
      setThemeMode(ThemeMode.dark);
    }
  }
}

final themeModeProvider = NotifierProvider<ThemeNotifier, ThemeMode>(() {
  return ThemeNotifier();
});
