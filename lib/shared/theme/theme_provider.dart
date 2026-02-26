import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models/theme_font_preset.dart';
import 'models/theme_preset.dart';
import 'models/theme_radius_preset.dart';
import 'models/theme_settings.dart';

export 'models/theme_preset.dart';
export 'models/theme_radius_preset.dart';
export 'models/theme_font_preset.dart';
export 'models/theme_settings.dart';

class ThemeSettingsNotifier extends Notifier<ThemeSettings> {
  static const _modeKey = 'theme_mode';
  static const _presetKey = 'theme_preset';
  static const _radiusPresetKey = 'theme_radius_preset';
  static const _fontPresetKey = 'theme_font_preset';

  SharedPreferences? _prefs;

  @override
  ThemeSettings build() {
    _hydrate();
    return const ThemeSettings();
  }

  Future<SharedPreferences> _getPrefs() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  Future<void> _hydrate() async {
    final prefs = await _getPrefs();
    final modeIndex = prefs.getInt(_modeKey);
    final mode = _modeFromIndex(modeIndex);
    final preset = ThemePresetX.fromStorage(prefs.getString(_presetKey));
    final radiusPreset = ThemeRadiusPresetX.fromStorage(
      prefs.getString(_radiusPresetKey),
      fallback: _legacyRadiusFallback(preset),
    );
    final fontPreset = ThemeFontPresetX.fromStorage(
      prefs.getString(_fontPresetKey),
    );

    if (!ref.mounted) return;
    state = state.copyWith(
      mode: mode,
      preset: preset,
      radiusPreset: radiusPreset,
      fontPreset: fontPreset,
    );
  }

  ThemeRadiusPreset _legacyRadiusFallback(ThemePreset preset) {
    switch (preset) {
      case ThemePreset.cohrtz:
        return ThemeRadiusPreset.rounded;
      case ThemePreset.gruvbox:
        return ThemeRadiusPreset.sharp;
      case ThemePreset.everforrest:
        return ThemeRadiusPreset.soft;
      case ThemePreset.catppuccinA:
      case ThemePreset.catppuccinB:
      case ThemePreset.catppuccinC:
      case ThemePreset.catppuccinMocha:
      case ThemePreset.nord:
      case ThemePreset.kanagowa:
      case ThemePreset.dracula:
      case ThemePreset.solarized:
      case ThemePreset.monokai:
      case ThemePreset.tokyonight:
      case ThemePreset.zenburn:
        return ThemeRadiusPreset.rounded;
    }
  }

  ThemeMode _modeFromIndex(int? index) {
    if (index == null) return const ThemeSettings().mode;
    if (index < 0 || index >= ThemeMode.values.length) {
      return const ThemeSettings().mode;
    }
    return ThemeMode.values[index];
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(mode: mode);
    final prefs = await _getPrefs();
    await prefs.setInt(_modeKey, mode.index);
  }

  Future<void> setThemePreset(ThemePreset preset) async {
    state = state.copyWith(preset: preset);
    final prefs = await _getPrefs();
    await prefs.setString(_presetKey, preset.storageValue);
  }

  Future<void> setRadiusPreset(ThemeRadiusPreset preset) async {
    state = state.copyWith(radiusPreset: preset);
    final prefs = await _getPrefs();
    await prefs.setString(_radiusPresetKey, preset.storageValue);
  }

  Future<void> setFontPreset(ThemeFontPreset preset) async {
    state = state.copyWith(fontPreset: preset);
    final prefs = await _getPrefs();
    await prefs.setString(_fontPresetKey, preset.storageValue);
  }

  Future<void> toggleThemeMode() async {
    final next = state.mode == ThemeMode.dark
        ? ThemeMode.light
        : ThemeMode.dark;
    await setThemeMode(next);
  }
}

final themeSettingsProvider =
    NotifierProvider<ThemeSettingsNotifier, ThemeSettings>(() {
      return ThemeSettingsNotifier();
    });

final themeModeProvider = Provider<ThemeMode>((ref) {
  return ref.watch(themeSettingsProvider.select((settings) => settings.mode));
});

final themePresetProvider = Provider<ThemePreset>((ref) {
  return ref.watch(themeSettingsProvider.select((settings) => settings.preset));
});

final themeRadiusPresetProvider = Provider<ThemeRadiusPreset>((ref) {
  return ref.watch(
    themeSettingsProvider.select((settings) => settings.radiusPreset),
  );
});

final themeFontPresetProvider = Provider<ThemeFontPreset>((ref) {
  return ref.watch(
    themeSettingsProvider.select((settings) => settings.fontPreset),
  );
});
