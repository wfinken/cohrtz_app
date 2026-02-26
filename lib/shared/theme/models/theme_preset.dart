enum ThemePreset {
  cohrtz,
  gruvbox,
  everforrest,
  catppuccinA,
  catppuccinB,
  catppuccinC,
  catppuccinMocha,
  nord,
  kanagowa,
  dracula,
  solarized,
  monokai,
  tokyonight,
  zenburn,
}

extension ThemePresetX on ThemePreset {
  String get label {
    switch (this) {
      case ThemePreset.cohrtz:
        return 'Cohrtz';
      case ThemePreset.gruvbox:
        return 'Gruvbox';
      case ThemePreset.everforrest:
        return 'Everforrest';
      case ThemePreset.catppuccinA:
        return 'Catppuccin A';
      case ThemePreset.catppuccinB:
        return 'Catppuccin B';
      case ThemePreset.catppuccinC:
        return 'Catppuccin C';
      case ThemePreset.catppuccinMocha:
        return 'Catppuccin Mocha';
      case ThemePreset.nord:
        return 'Nord';
      case ThemePreset.kanagowa:
        return 'Kanagowa';
      case ThemePreset.dracula:
        return 'Dracula';
      case ThemePreset.solarized:
        return 'Solarized';
      case ThemePreset.monokai:
        return 'Monokai';
      case ThemePreset.tokyonight:
        return 'Tokyo Night';
      case ThemePreset.zenburn:
        return 'Zenburn';
    }
  }

  String get storageValue => name;

  static ThemePreset fromStorage(String? value) {
    for (final preset in ThemePreset.values) {
      if (preset.storageValue == value) {
        return preset;
      }
    }
    return ThemePreset.cohrtz;
  }
}
