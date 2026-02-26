import 'package:cohortz/shared/theme/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _waitFor(
  ProviderContainer container, {
  required ThemeMode mode,
  required ThemePreset preset,
  ThemeRadiusPreset radiusPreset = ThemeRadiusPreset.rounded,
  ThemeFontPreset fontPreset = ThemeFontPreset.inter,
}) async {
  for (var i = 0; i < 60; i++) {
    final current = container.read(themeSettingsProvider);
    if (current.mode == mode &&
        current.preset == preset &&
        current.radiusPreset == radiusPreset &&
        current.fontPreset == fontPreset) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  final current = container.read(themeSettingsProvider);
  throw TestFailure(
    'Timed out waiting for theme settings. '
    'Expected mode=$mode preset=$preset radius=$radiusPreset font=$fontPreset, '
    'got mode=${current.mode} preset=${current.preset} '
    'radius=${current.radiusPreset} font=${current.fontPreset}.',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('uses default theme settings before hydration', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(themeSettingsProvider), const ThemeSettings());
  });

  test('hydrates theme mode and preset from shared preferences', () async {
    SharedPreferences.setMockInitialValues({
      'theme_mode': ThemeMode.system.index,
      'theme_preset': ThemePreset.gruvbox.storageValue,
      'theme_radius_preset': ThemeRadiusPreset.sharp.storageValue,
      'theme_font_preset': ThemeFontPreset.nunitoSans.storageValue,
    });

    final container = ProviderContainer();
    addTearDown(container.dispose);
    final sub = container.listen(themeSettingsProvider, (_, __) {});
    addTearDown(sub.close);

    await _waitFor(
      container,
      mode: ThemeMode.system,
      preset: ThemePreset.gruvbox,
      radiusPreset: ThemeRadiusPreset.sharp,
      fontPreset: ThemeFontPreset.nunitoSans,
    );
  });

  test('hydrates everforrest preset from shared preferences', () async {
    SharedPreferences.setMockInitialValues({
      'theme_mode': ThemeMode.dark.index,
      'theme_preset': ThemePreset.everforrest.storageValue,
      'theme_radius_preset': ThemeRadiusPreset.diagonal.storageValue,
      'theme_font_preset': ThemeFontPreset.manrope.storageValue,
    });

    final container = ProviderContainer();
    addTearDown(container.dispose);
    final sub = container.listen(themeSettingsProvider, (_, __) {});
    addTearDown(sub.close);

    await _waitFor(
      container,
      mode: ThemeMode.dark,
      preset: ThemePreset.everforrest,
      radiusPreset: ThemeRadiusPreset.diagonal,
      fontPreset: ThemeFontPreset.manrope,
    );
  });

  test('hydrates catppuccin mocha preset from shared preferences', () async {
    SharedPreferences.setMockInitialValues({
      'theme_mode': ThemeMode.system.index,
      'theme_preset': ThemePreset.catppuccinMocha.storageValue,
      'theme_radius_preset': ThemeRadiusPreset.rounded.storageValue,
      'theme_font_preset': ThemeFontPreset.firaSans.storageValue,
    });

    final container = ProviderContainer();
    addTearDown(container.dispose);
    final sub = container.listen(themeSettingsProvider, (_, __) {});
    addTearDown(sub.close);

    await _waitFor(
      container,
      mode: ThemeMode.system,
      preset: ThemePreset.catppuccinMocha,
      radiusPreset: ThemeRadiusPreset.rounded,
      fontPreset: ThemeFontPreset.firaSans,
    );
  });

  test('hydrates tokyonight preset from shared preferences', () async {
    SharedPreferences.setMockInitialValues({
      'theme_mode': ThemeMode.dark.index,
      'theme_preset': ThemePreset.tokyonight.storageValue,
      'theme_radius_preset': ThemeRadiusPreset.rounded.storageValue,
      'theme_font_preset': ThemeFontPreset.inter.storageValue,
    });

    final container = ProviderContainer();
    addTearDown(container.dispose);
    final sub = container.listen(themeSettingsProvider, (_, __) {});
    addTearDown(sub.close);

    await _waitFor(
      container,
      mode: ThemeMode.dark,
      preset: ThemePreset.tokyonight,
      radiusPreset: ThemeRadiusPreset.rounded,
      fontPreset: ThemeFontPreset.inter,
    );
  });

  test('falls back to default preset when old storage has only mode', () async {
    SharedPreferences.setMockInitialValues({
      'theme_mode': ThemeMode.light.index,
    });

    final container = ProviderContainer();
    addTearDown(container.dispose);
    final sub = container.listen(themeSettingsProvider, (_, __) {});
    addTearDown(sub.close);

    await _waitFor(
      container,
      mode: ThemeMode.light,
      preset: ThemePreset.cohrtz,
      radiusPreset: ThemeRadiusPreset.rounded,
      fontPreset: ThemeFontPreset.inter,
    );
  });

  test('falls back to legacy radius when only preset is stored', () async {
    SharedPreferences.setMockInitialValues({
      'theme_preset': ThemePreset.gruvbox.storageValue,
    });

    final container = ProviderContainer();
    addTearDown(container.dispose);
    final sub = container.listen(themeSettingsProvider, (_, __) {});
    addTearDown(sub.close);

    await _waitFor(
      container,
      mode: ThemeMode.dark,
      preset: ThemePreset.gruvbox,
      radiusPreset: ThemeRadiusPreset.sharp,
      fontPreset: ThemeFontPreset.inter,
    );
  });

  test('persists mode and preset changes', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container
        .read(themeSettingsProvider.notifier)
        .setThemeMode(ThemeMode.light);
    await container
        .read(themeSettingsProvider.notifier)
        .setThemePreset(ThemePreset.gruvbox);
    await container
        .read(themeSettingsProvider.notifier)
        .setRadiusPreset(ThemeRadiusPreset.diagonal);
    await container
        .read(themeSettingsProvider.notifier)
        .setFontPreset(ThemeFontPreset.sourceSans3);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('theme_mode'), ThemeMode.light.index);
    expect(prefs.getString('theme_preset'), ThemePreset.gruvbox.storageValue);
    expect(
      prefs.getString('theme_radius_preset'),
      ThemeRadiusPreset.diagonal.storageValue,
    );
    expect(
      prefs.getString('theme_font_preset'),
      ThemeFontPreset.sourceSans3.storageValue,
    );

    final settings = container.read(themeSettingsProvider);
    expect(settings.mode, ThemeMode.light);
    expect(settings.preset, ThemePreset.gruvbox);
    expect(settings.radiusPreset, ThemeRadiusPreset.diagonal);
    expect(settings.fontPreset, ThemeFontPreset.sourceSans3);
  });
}
