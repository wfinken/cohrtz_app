import 'package:flutter/material.dart';

import 'theme_font_preset.dart';
import 'theme_preset.dart';
import 'theme_radius_preset.dart';

@immutable
class ThemeSettings {
  const ThemeSettings({
    this.mode = ThemeMode.dark,
    this.preset = ThemePreset.cohrtz,
    this.radiusPreset = ThemeRadiusPreset.rounded,
    this.fontPreset = ThemeFontPreset.inter,
  });

  final ThemeMode mode;
  final ThemePreset preset;
  final ThemeRadiusPreset radiusPreset;
  final ThemeFontPreset fontPreset;

  ThemeSettings copyWith({
    ThemeMode? mode,
    ThemePreset? preset,
    ThemeRadiusPreset? radiusPreset,
    ThemeFontPreset? fontPreset,
  }) {
    return ThemeSettings(
      mode: mode ?? this.mode,
      preset: preset ?? this.preset,
      radiusPreset: radiusPreset ?? this.radiusPreset,
      fontPreset: fontPreset ?? this.fontPreset,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ThemeSettings &&
        other.mode == mode &&
        other.preset == preset &&
        other.radiusPreset == radiusPreset &&
        other.fontPreset == fontPreset;
  }

  @override
  int get hashCode => Object.hash(mode, preset, radiusPreset, fontPreset);
}
