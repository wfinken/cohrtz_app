enum ThemeRadiusPreset { rounded, soft, sharp, diagonal }

extension ThemeRadiusPresetX on ThemeRadiusPreset {
  String get label {
    switch (this) {
      case ThemeRadiusPreset.rounded:
        return 'Rounded';
      case ThemeRadiusPreset.soft:
        return 'Soft';
      case ThemeRadiusPreset.sharp:
        return 'Sharp';
      case ThemeRadiusPreset.diagonal:
        return 'Diagonal';
    }
  }

  String get description {
    switch (this) {
      case ThemeRadiusPreset.rounded:
        return 'Balanced corners across cards and controls.';
      case ThemeRadiusPreset.soft:
        return 'More rounded corners for a softer appearance.';
      case ThemeRadiusPreset.sharp:
        return 'Square corners for a crisp layout.';
      case ThemeRadiusPreset.diagonal:
        return 'Top-left and bottom-right are squared off.';
    }
  }

  String get storageValue => name;

  static ThemeRadiusPreset fromStorage(
    String? value, {
    ThemeRadiusPreset fallback = ThemeRadiusPreset.rounded,
  }) {
    for (final preset in ThemeRadiusPreset.values) {
      if (preset.storageValue == value) {
        return preset;
      }
    }
    return fallback;
  }
}
