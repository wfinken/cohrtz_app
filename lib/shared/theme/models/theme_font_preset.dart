enum ThemeFontPreset { inter, manrope, firaSans, nunitoSans, sourceSans3 }

extension ThemeFontPresetX on ThemeFontPreset {
  String get label {
    switch (this) {
      case ThemeFontPreset.inter:
        return 'Inter';
      case ThemeFontPreset.manrope:
        return 'Manrope';
      case ThemeFontPreset.firaSans:
        return 'Fira Sans';
      case ThemeFontPreset.nunitoSans:
        return 'Nunito Sans';
      case ThemeFontPreset.sourceSans3:
        return 'Source Sans 3';
    }
  }

  String get storageValue => name;

  static ThemeFontPreset fromStorage(
    String? value, {
    ThemeFontPreset fallback = ThemeFontPreset.inter,
  }) {
    for (final preset in ThemeFontPreset.values) {
      if (preset.storageValue == value) {
        return preset;
      }
    }
    return fallback;
  }
}
