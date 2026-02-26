import 'package:cohortz/shared/theme/models/theme_font_preset.dart';
import 'package:cohortz/shared/theme/models/theme_preset.dart';
import 'package:cohortz/shared/theme/models/theme_radius_preset.dart';
import 'package:cohortz/shared/theme/models/theme_settings.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';
import 'app_semantic_colors.dart';
import 'app_shape_tokens.dart';

/// Centralized theme configuration for the Cohrtz app.
class AppTheme {
  AppTheme._();

  static ThemeData resolve({
    required ThemeSettings settings,
    required Brightness brightness,
  }) {
    return _theme(settings, brightness);
  }

  static ThemeData lightForSettings(ThemeSettings settings) {
    return _theme(settings, Brightness.light);
  }

  static ThemeData darkForSettings(ThemeSettings settings) {
    return _theme(settings, Brightness.dark);
  }

  // Backward-compatible API for callsites/tests that still pass only ThemePreset.
  static ThemeData lightFor(ThemePreset preset) {
    return _theme(_legacySettingsForPreset(preset), Brightness.light);
  }

  static ThemeData darkFor(ThemePreset preset) {
    return _theme(_legacySettingsForPreset(preset), Brightness.dark);
  }

  // Backward-compatible defaults for any callsites not yet migrated.
  static ThemeData get light => lightFor(ThemePreset.cohrtz);
  static ThemeData get dark => darkFor(ThemePreset.cohrtz);

  static ThemeSettings _legacySettingsForPreset(ThemePreset preset) {
    switch (preset) {
      case ThemePreset.cohrtz:
        return const ThemeSettings(
          preset: ThemePreset.cohrtz,
          radiusPreset: ThemeRadiusPreset.rounded,
          fontPreset: ThemeFontPreset.inter,
        );
      case ThemePreset.gruvbox:
        return const ThemeSettings(
          preset: ThemePreset.gruvbox,
          radiusPreset: ThemeRadiusPreset.sharp,
          fontPreset: ThemeFontPreset.inter,
        );
      case ThemePreset.everforrest:
        return const ThemeSettings(
          preset: ThemePreset.everforrest,
          radiusPreset: ThemeRadiusPreset.soft,
          fontPreset: ThemeFontPreset.inter,
        );
      case ThemePreset.catppuccinA:
        return const ThemeSettings(
          preset: ThemePreset.catppuccinA,
          radiusPreset: ThemeRadiusPreset.rounded,
          fontPreset: ThemeFontPreset.inter,
        );
      case ThemePreset.catppuccinB:
        return const ThemeSettings(
          preset: ThemePreset.catppuccinB,
          radiusPreset: ThemeRadiusPreset.rounded,
          fontPreset: ThemeFontPreset.inter,
        );
      case ThemePreset.catppuccinC:
        return const ThemeSettings(
          preset: ThemePreset.catppuccinC,
          radiusPreset: ThemeRadiusPreset.rounded,
          fontPreset: ThemeFontPreset.inter,
        );
      case ThemePreset.catppuccinMocha:
        return const ThemeSettings(
          preset: ThemePreset.catppuccinMocha,
          radiusPreset: ThemeRadiusPreset.rounded,
          fontPreset: ThemeFontPreset.inter,
        );
      case ThemePreset.nord:
        return const ThemeSettings(
          preset: ThemePreset.nord,
          radiusPreset: ThemeRadiusPreset.rounded,
          fontPreset: ThemeFontPreset.inter,
        );
      case ThemePreset.kanagowa:
        return const ThemeSettings(
          preset: ThemePreset.kanagowa,
          radiusPreset: ThemeRadiusPreset.rounded,
          fontPreset: ThemeFontPreset.inter,
        );
      case ThemePreset.dracula:
        return const ThemeSettings(
          preset: ThemePreset.dracula,
          radiusPreset: ThemeRadiusPreset.rounded,
          fontPreset: ThemeFontPreset.inter,
        );
      case ThemePreset.solarized:
        return const ThemeSettings(
          preset: ThemePreset.solarized,
          radiusPreset: ThemeRadiusPreset.rounded,
          fontPreset: ThemeFontPreset.inter,
        );
      case ThemePreset.monokai:
        return const ThemeSettings(
          preset: ThemePreset.monokai,
          radiusPreset: ThemeRadiusPreset.rounded,
          fontPreset: ThemeFontPreset.inter,
        );
      case ThemePreset.tokyonight:
        return const ThemeSettings(
          preset: ThemePreset.tokyonight,
          radiusPreset: ThemeRadiusPreset.rounded,
          fontPreset: ThemeFontPreset.inter,
        );
      case ThemePreset.zenburn:
        return const ThemeSettings(
          preset: ThemePreset.zenburn,
          radiusPreset: ThemeRadiusPreset.rounded,
          fontPreset: ThemeFontPreset.inter,
        );
    }
  }

  static ThemeData _theme(ThemeSettings settings, Brightness brightness) {
    final preset = settings.preset;
    final fontPreset = settings.fontPreset;
    final isDark = brightness == Brightness.dark;
    final colorScheme = _colorScheme(preset, brightness);
    final shapes = _shapeTokens(settings.radiusPreset);
    final semanticColors = _semanticColors(preset, isDark);

    final baseTheme = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: _pageColor(preset, isDark),
      canvasColor: colorScheme.surface,
      dividerColor: colorScheme.outlineVariant,
      hintColor: colorScheme.onSurfaceVariant,
      splashFactory: InkRipple.splashFactory,
    );

    final textTheme = _baseTextTheme(fontPreset)
        .copyWith(
          titleLarge: _font(
            fontPreset,
            color: colorScheme.onSurface,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
          titleMedium: _font(
            fontPreset,
            color: colorScheme.onSurface,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          bodyLarge: _font(
            fontPreset,
            color: colorScheme.onSurface,
            fontSize: 16,
          ),
          bodyMedium: _font(
            fontPreset,
            color: colorScheme.onSurface,
            fontSize: 14,
          ),
          bodySmall: _font(
            fontPreset,
            color: colorScheme.onSurfaceVariant,
            fontSize: 12,
          ),
          labelSmall: _font(
            fontPreset,
            color: colorScheme.onSurfaceVariant,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.6,
          ),
        )
        .apply(
          bodyColor: colorScheme.onSurface,
          displayColor: colorScheme.onSurface,
        );

    return baseTheme.copyWith(
      extensions: <ThemeExtension<dynamic>>[semanticColors, shapes],
      textTheme: textTheme,
      iconTheme: IconThemeData(color: colorScheme.onSurfaceVariant),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colorScheme.primary,
        linearTrackColor: colorScheme.surfaceContainerHigh,
        linearMinHeight: 8,
        borderRadius: shapes.borderRadius(shapes.elementRadius),
      ),
      cardTheme: CardThemeData(
        color: colorScheme.surface,
        elevation: 0.5,
        shadowColor: colorScheme.shadow,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: shapes.borderRadius(shapes.cardRadius),
          side: BorderSide(color: colorScheme.outlineVariant, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _inputFillColor(preset, isDark, colorScheme),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        hintStyle: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 14),
        border: OutlineInputBorder(
          borderRadius: shapes.borderRadius(shapes.elementRadius),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: shapes.borderRadius(shapes.elementRadius),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: shapes.borderRadius(shapes.elementRadius),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: shapes.borderRadius(shapes.elementRadius),
          borderSide: BorderSide(color: colorScheme.error),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style:
            ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
              elevation: 0,
              shadowColor: colorScheme.primary.withValues(alpha: 0.35),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: shapes.borderRadius(shapes.elementRadius),
              ),
              textStyle: _font(
                fontPreset,
                fontWeight: FontWeight.w600,
                color: colorScheme.onPrimary,
              ),
            ).copyWith(
              side: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.disabled)) {
                  return BorderSide.none;
                }
                return BorderSide(
                  color: colorScheme.primary.withValues(alpha: 0.25),
                  width: 1,
                );
              }),
            ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.onSurface,
          side: BorderSide(color: colorScheme.outlineVariant),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: shapes.borderRadius(shapes.elementRadius),
          ),
          textStyle: _font(
            fontPreset,
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: shapes.borderRadius(shapes.elementRadius),
          ),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: shapes.borderRadius(shapes.elementRadius),
            ),
          ),
        ),
      ),
      chipTheme: baseTheme.chipTheme.copyWith(
        shape: RoundedRectangleBorder(
          borderRadius: shapes.borderRadius(shapes.elementRadius),
        ),
      ),
      dialogTheme: DialogThemeData(
        barrierColor: Colors.black.withValues(alpha: 0.42),
        backgroundColor: colorScheme.surface.withValues(alpha: 0.96),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shadowColor: colorScheme.shadow,
        alignment: Alignment.center,
        actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        titleTextStyle: _font(
          fontPreset,
          color: colorScheme.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
        contentTextStyle: _font(
          fontPreset,
          color: colorScheme.onSurfaceVariant,
          fontSize: 15,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: shapes.borderRadius(shapes.dialogRadius),
          side: BorderSide(color: colorScheme.outlineVariant, width: 1),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: colorScheme.onSurfaceVariant),
        titleTextStyle: _font(
          fontPreset,
          color: colorScheme.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: colorScheme.surfaceContainerHigh,
        shadowColor: colorScheme.shadow,
        shape: RoundedRectangleBorder(
          borderRadius: shapes.borderRadius(shapes.menuRadius),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: shapes.borderRadius(shapes.elementRadius),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: shapes.borderRadius(shapes.dialogRadius),
        ),
      ),
    );
  }

  static AppShapeTokens _shapeTokens(ThemeRadiusPreset preset) {
    return AppShapeTokens.fromPreset(preset);
  }

  static AppSemanticColors _semanticColors(ThemePreset preset, bool isDark) {
    switch (preset) {
      case ThemePreset.cohrtz:
        return isDark ? AppSemanticColors.dark() : AppSemanticColors.light();
      case ThemePreset.gruvbox:
        return isDark
            ? const AppSemanticColors(
                success: Color(0xFFB8BB26),
                warning: Color(0xFFFABD2F),
                danger: Color(0xFFFB4934),
                info: Color(0xFF83A598),
                accentMuted: Color(0xFF3C3836),
                skeletonBase: Color(0xFF3C3836),
                skeletonHighlight: Color(0xFF504945),
              )
            : const AppSemanticColors(
                success: Color(0xFF98971A),
                warning: Color(0xFFD79921),
                danger: Color(0xFFCC241D),
                info: Color(0xFF458588),
                accentMuted: Color(0xFFEBD9A6),
                skeletonBase: Color(0xFFD5C4A1),
                skeletonHighlight: Color(0xFFEBDBB2),
              );
      case ThemePreset.everforrest:
        return isDark
            ? const AppSemanticColors(
                success: Color(0xFFA7C080),
                warning: Color(0xFFDBBC7F),
                danger: Color(0xFFE67E80),
                info: Color(0xFF7FBBB3),
                accentMuted: Color(0xFF3D484D),
                skeletonBase: Color(0xFF3D484D),
                skeletonHighlight: Color(0xFF475258),
              )
            : const AppSemanticColors(
                success: Color(0xFF8DA101),
                warning: Color(0xFFDFA000),
                danger: Color(0xFFF85552),
                info: Color(0xFF3A94C5),
                accentMuted: Color(0xFFEDEADA),
                skeletonBase: Color(0xFFE8E5D5),
                skeletonHighlight: Color(0xFFF2EFDF),
              );
      case ThemePreset.catppuccinA:
        return isDark
            ? const AppSemanticColors(
                success: Color(0xFFA6D189),
                warning: Color(0xFFE5C890),
                danger: Color(0xFFE78284),
                info: Color(0xFF8CAAEE),
                accentMuted: Color(0xFF414559),
                skeletonBase: Color(0xFF414559),
                skeletonHighlight: Color(0xFF51576D),
              )
            : const AppSemanticColors(
                success: Color(0xFF40A02B),
                warning: Color(0xFFDF8E1D),
                danger: Color(0xFFD20F39),
                info: Color(0xFF1E66F5),
                accentMuted: Color(0xFFE6E9EF),
                skeletonBase: Color(0xFFDCE0E8),
                skeletonHighlight: Color(0xFFE6E9EF),
              );
      case ThemePreset.catppuccinB:
        return isDark
            ? const AppSemanticColors(
                success: Color(0xFFA6DA95),
                warning: Color(0xFFEED49F),
                danger: Color(0xFFED8796),
                info: Color(0xFF8AADF4),
                accentMuted: Color(0xFF363A4F),
                skeletonBase: Color(0xFF363A4F),
                skeletonHighlight: Color(0xFF494D64),
              )
            : const AppSemanticColors(
                success: Color(0xFF40A02B),
                warning: Color(0xFFFE640B),
                danger: Color(0xFFD20F39),
                info: Color(0xFF8839EF),
                accentMuted: Color(0xFFE6E9EF),
                skeletonBase: Color(0xFFDCE0E8),
                skeletonHighlight: Color(0xFFE6E9EF),
              );
      case ThemePreset.catppuccinC:
        return isDark
            ? const AppSemanticColors(
                success: Color(0xFFA6E3A1),
                warning: Color(0xFFFAB387),
                danger: Color(0xFFF38BA8),
                info: Color(0xFF89B4FA),
                accentMuted: Color(0xFF313244),
                skeletonBase: Color(0xFF313244),
                skeletonHighlight: Color(0xFF45475A),
              )
            : const AppSemanticColors(
                success: Color(0xFF40A02B),
                warning: Color(0xFFFE640B),
                danger: Color(0xFFD20F39),
                info: Color(0xFF1E66F5),
                accentMuted: Color(0xFFE6E9EF),
                skeletonBase: Color(0xFFDCE0E8),
                skeletonHighlight: Color(0xFFE6E9EF),
              );
      case ThemePreset.catppuccinMocha:
        return isDark
            ? const AppSemanticColors(
                success: Color(0xFFA6E3A1),
                warning: Color(0xFFF9E2AF),
                danger: Color(0xFFF38BA8),
                info: Color(0xFFCBA6F7),
                accentMuted: Color(0xFF313244),
                skeletonBase: Color(0xFF313244),
                skeletonHighlight: Color(0xFF45475A),
              )
            : const AppSemanticColors(
                success: Color(0xFF40A02B),
                warning: Color(0xFFDF8E1D),
                danger: Color(0xFFD20F39),
                info: Color(0xFF8839EF),
                accentMuted: Color(0xFFE6E9EF),
                skeletonBase: Color(0xFFDCE0E8),
                skeletonHighlight: Color(0xFFE6E9EF),
              );
      case ThemePreset.nord:
        return isDark
            ? const AppSemanticColors(
                success: Color(0xFFA3BE8C),
                warning: Color(0xFFEBCB8B),
                danger: Color(0xFFBF616A),
                info: Color(0xFF88C0D0),
                accentMuted: Color(0xFF434C5E),
                skeletonBase: Color(0xFF434C5E),
                skeletonHighlight: Color(0xFF4C566A),
              )
            : const AppSemanticColors(
                success: Color(0xFF5E815B),
                warning: Color(0xFFB48E38),
                danger: Color(0xFFBF616A),
                info: Color(0xFF5E81AC),
                accentMuted: Color(0xFFE5E9F0),
                skeletonBase: Color(0xFFD8DEE9),
                skeletonHighlight: Color(0xFFECEFF4),
              );
      case ThemePreset.kanagowa:
        return isDark
            ? const AppSemanticColors(
                success: Color(0xFF98BB6C),
                warning: Color(0xFFE6C384),
                danger: Color(0xFFC34043),
                info: Color(0xFF7E9CD8),
                accentMuted: Color(0xFF2A2A37),
                skeletonBase: Color(0xFF2A2A37),
                skeletonHighlight: Color(0xFF363646),
              )
            : const AppSemanticColors(
                success: Color(0xFF6F894E),
                warning: Color(0xFFC79C4E),
                danger: Color(0xFFC34043),
                info: Color(0xFF4D699B),
                accentMuted: Color(0xFFEDE3C9),
                skeletonBase: Color(0xFFE2D6B6),
                skeletonHighlight: Color(0xFFF2ECBC),
              );
      case ThemePreset.dracula:
        return isDark
            ? const AppSemanticColors(
                success: Color(0xFF50FA7B),
                warning: Color(0xFFF1FA8C),
                danger: Color(0xFFFF5555),
                info: Color(0xFF8BE9FD),
                accentMuted: Color(0xFF44475A),
                skeletonBase: Color(0xFF44475A),
                skeletonHighlight: Color(0xFF6272A4),
              )
            : const AppSemanticColors(
                success: Color(0xFF50A464),
                warning: Color(0xFFCAA64A),
                danger: Color(0xFFD95B6A),
                info: Color(0xFF4F8CC9),
                accentMuted: Color(0xFFE8E7F5),
                skeletonBase: Color(0xFFDBD9EA),
                skeletonHighlight: Color(0xFFF2F1FB),
              );
      case ThemePreset.solarized:
        return const AppSemanticColors(
          success: Color(0xFF859900),
          warning: Color(0xFFB58900),
          danger: Color(0xFFDC322F),
          info: Color(0xFF268BD2),
          accentMuted: Color(0xFFEEE8D5),
          skeletonBase: Color(0xFFEEE8D5),
          skeletonHighlight: Color(0xFFFDF6E3),
        );
      case ThemePreset.monokai:
        return isDark
            ? const AppSemanticColors(
                success: Color(0xFFA6E22E),
                warning: Color(0xFFF4BF75),
                danger: Color(0xFFF92672),
                info: Color(0xFF66D9EF),
                accentMuted: Color(0xFF383830),
                skeletonBase: Color(0xFF383830),
                skeletonHighlight: Color(0xFF49483E),
              )
            : const AppSemanticColors(
                success: Color(0xFF7D9F28),
                warning: Color(0xFFC28C44),
                danger: Color(0xFFC44D75),
                info: Color(0xFF3FA9BE),
                accentMuted: Color(0xFFE8E8DD),
                skeletonBase: Color(0xFFDDDDD1),
                skeletonHighlight: Color(0xFFF6F6EF),
              );
      case ThemePreset.tokyonight:
        return isDark
            ? const AppSemanticColors(
                success: Color(0xFF9ECE6A),
                warning: Color(0xFFE0AF68),
                danger: Color(0xFFF7768E),
                info: Color(0xFF7AA2F7),
                accentMuted: Color(0xFF24283B),
                skeletonBase: Color(0xFF24283B),
                skeletonHighlight: Color(0xFF414868),
              )
            : const AppSemanticColors(
                success: Color(0xFF587539),
                warning: Color(0xFF8C6A2D),
                danger: Color(0xFFC53B53),
                info: Color(0xFF3760BF),
                accentMuted: Color(0xFFD5D6DB),
                skeletonBase: Color(0xFFD5D6DB),
                skeletonHighlight: Color(0xFFE1E2E7),
              );
      case ThemePreset.zenburn:
        return isDark
            ? const AppSemanticColors(
                success: Color(0xFF9FC59F),
                warning: Color(0xFFF0DFAF),
                danger: Color(0xFFCC9393),
                info: Color(0xFF8CD0D3),
                accentMuted: Color(0xFF4F4F4F),
                skeletonBase: Color(0xFF4F4F4F),
                skeletonHighlight: Color(0xFF5F5F5F),
              )
            : const AppSemanticColors(
                success: Color(0xFF6E8F6E),
                warning: Color(0xFFBEAB7A),
                danger: Color(0xFFA96F6F),
                info: Color(0xFF5A8A8A),
                accentMuted: Color(0xFFE8E4CF),
                skeletonBase: Color(0xFFE1DBC3),
                skeletonHighlight: Color(0xFFF5F3E8),
              );
    }
  }

  static ColorScheme _colorScheme(ThemePreset preset, Brightness brightness) {
    switch (preset) {
      case ThemePreset.cohrtz:
        return _cohrtzColorScheme(brightness);
      case ThemePreset.gruvbox:
        return _gruvboxColorScheme(brightness);
      case ThemePreset.everforrest:
        return _everforrestColorScheme(brightness);
      case ThemePreset.catppuccinA:
        return _catppuccinAColorScheme(brightness);
      case ThemePreset.catppuccinB:
        return _catppuccinBColorScheme(brightness);
      case ThemePreset.catppuccinC:
        return _catppuccinCColorScheme(brightness);
      case ThemePreset.catppuccinMocha:
        return _catppuccinMochaColorScheme(brightness);
      case ThemePreset.nord:
        return _nordColorScheme(brightness);
      case ThemePreset.kanagowa:
        return _kanagowaColorScheme(brightness);
      case ThemePreset.dracula:
        return _draculaColorScheme(brightness);
      case ThemePreset.solarized:
        return _solarizedColorScheme(brightness);
      case ThemePreset.monokai:
        return _monokaiColorScheme(brightness);
      case ThemePreset.tokyonight:
        return _tokyoNightColorScheme(brightness);
      case ThemePreset.zenburn:
        return _zenburnColorScheme(brightness);
    }
  }

  static Color _pageColor(ThemePreset preset, bool isDark) {
    switch (preset) {
      case ThemePreset.cohrtz:
        return isDark ? AppColors.darkPage : AppColors.lightPage;
      case ThemePreset.gruvbox:
        return isDark ? const Color(0xFF1D2021) : const Color(0xFFFBF1C7);
      case ThemePreset.everforrest:
        return isDark ? const Color(0xFF232A2E) : const Color(0xFFFFFBEF);
      case ThemePreset.catppuccinA:
        return isDark ? const Color(0xFF303446) : const Color(0xFFEFF1F5);
      case ThemePreset.catppuccinB:
        return isDark ? const Color(0xFF24273A) : const Color(0xFFEFF1F5);
      case ThemePreset.catppuccinC:
      case ThemePreset.catppuccinMocha:
        return isDark ? const Color(0xFF1E1E2E) : const Color(0xFFEFF1F5);
      case ThemePreset.nord:
        return isDark ? const Color(0xFF2E3440) : const Color(0xFFECEFF4);
      case ThemePreset.kanagowa:
        return isDark ? const Color(0xFF1F1F28) : const Color(0xFFF2ECBC);
      case ThemePreset.dracula:
        return isDark ? const Color(0xFF282A36) : const Color(0xFFF7F7FB);
      case ThemePreset.solarized:
        return isDark ? const Color(0xFF002B36) : const Color(0xFFFDF6E3);
      case ThemePreset.monokai:
        return isDark ? const Color(0xFF272822) : const Color(0xFFF8F8F2);
      case ThemePreset.tokyonight:
        return isDark ? const Color(0xFF1A1B26) : const Color(0xFFE1E2E7);
      case ThemePreset.zenburn:
        return isDark ? const Color(0xFF3F3F3F) : const Color(0xFFF5F3E8);
    }
  }

  static Color _inputFillColor(
    ThemePreset preset,
    bool isDark,
    ColorScheme colorScheme,
  ) {
    switch (preset) {
      case ThemePreset.cohrtz:
        return isDark
            ? AppColors.slate900.withValues(alpha: 0.50)
            : colorScheme.surfaceContainerLow;
      case ThemePreset.gruvbox:
        return isDark
            ? colorScheme.surfaceContainerHigh.withValues(alpha: 0.72)
            : colorScheme.surfaceContainerLow;
      case ThemePreset.everforrest:
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
        return isDark
            ? colorScheme.surfaceContainerHigh.withValues(alpha: 0.72)
            : colorScheme.surfaceContainerLow;
    }
  }

  static TextTheme _baseTextTheme(ThemeFontPreset preset) {
    switch (preset) {
      case ThemeFontPreset.inter:
        return GoogleFonts.interTextTheme();
      case ThemeFontPreset.manrope:
        return GoogleFonts.manropeTextTheme();
      case ThemeFontPreset.firaSans:
        return GoogleFonts.firaSansTextTheme();
      case ThemeFontPreset.nunitoSans:
        return GoogleFonts.nunitoSansTextTheme();
      case ThemeFontPreset.sourceSans3:
        return GoogleFonts.sourceSans3TextTheme();
    }
  }

  static TextStyle _font(
    ThemeFontPreset preset, {
    required Color color,
    double? fontSize,
    FontWeight? fontWeight,
    double? letterSpacing,
  }) {
    switch (preset) {
      case ThemeFontPreset.inter:
        return GoogleFonts.inter(
          color: color,
          fontSize: fontSize,
          fontWeight: fontWeight,
          letterSpacing: letterSpacing,
        );
      case ThemeFontPreset.manrope:
        return GoogleFonts.manrope(
          color: color,
          fontSize: fontSize,
          fontWeight: fontWeight,
          letterSpacing: letterSpacing,
        );
      case ThemeFontPreset.firaSans:
        return GoogleFonts.firaSans(
          color: color,
          fontSize: fontSize,
          fontWeight: fontWeight,
          letterSpacing: letterSpacing,
        );
      case ThemeFontPreset.nunitoSans:
        return GoogleFonts.nunitoSans(
          color: color,
          fontSize: fontSize,
          fontWeight: fontWeight,
          letterSpacing: letterSpacing,
        );
      case ThemeFontPreset.sourceSans3:
        return GoogleFonts.sourceSans3(
          color: color,
          fontSize: fontSize,
          fontWeight: fontWeight,
          letterSpacing: letterSpacing,
        );
    }
  }

  static ColorScheme _cohrtzColorScheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final baseColorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.accent,
      brightness: brightness,
    );
    return baseColorScheme.copyWith(
      primary: AppColors.accent,
      secondary: AppColors.accent,
      tertiary: AppColors.accent,
      surface: isDark ? AppColors.darkCard : AppColors.lightCard,
      surfaceContainerLowest: isDark
          ? const Color(0xFF0E0E12)
          : AppColors.lightCard,
      surfaceContainerLow: isDark
          ? const Color(0xFF13131A)
          : const Color(0xFFF1F5F9),
      surfaceContainer: isDark ? const Color(0xFF181821) : AppColors.lightCard,
      surfaceContainerHigh: isDark
          ? const Color(0xFF20202B)
          : const Color(0xFFF1F5F9),
      surfaceContainerHighest: isDark
          ? const Color(0xFF262634)
          : const Color(0xFFE2E8F0),
      onSurface: isDark ? Colors.white : AppColors.slate900,
      onSurfaceVariant: AppColors.slate500,
      outline: isDark ? AppColors.darkBorder : AppColors.lightBorder,
      outlineVariant: isDark
          ? AppColors.slate800.withValues(alpha: 0.5)
          : AppColors.lightBorder,
      shadow: isDark
          ? Colors.black.withValues(alpha: 0.10)
          : AppColors.slate700.withValues(alpha: 0.05),
      scrim: Colors.black.withValues(alpha: 0.45),
    );
  }

  static ColorScheme _gruvboxColorScheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final baseColorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF458588),
      brightness: brightness,
    );

    if (isDark) {
      return baseColorScheme.copyWith(
        primary: const Color(0xFF83A598),
        onPrimary: const Color(0xFF1D2021),
        secondary: const Color(0xFF8EC07C),
        onSecondary: const Color(0xFF1D2021),
        tertiary: const Color(0xFFFABD2F),
        onTertiary: const Color(0xFF1D2021),
        error: const Color(0xFFFB4934),
        onError: const Color(0xFF1D2021),
        surface: const Color(0xFF282828),
        surfaceContainerLowest: const Color(0xFF1D2021),
        surfaceContainerLow: const Color(0xFF282828),
        surfaceContainer: const Color(0xFF32302F),
        surfaceContainerHigh: const Color(0xFF3C3836),
        surfaceContainerHighest: const Color(0xFF504945),
        onSurface: const Color(0xFFEBDBB2),
        onSurfaceVariant: const Color(0xFFBDAE93),
        outline: const Color(0xFF665C54),
        outlineVariant: const Color(0xFF504945),
        shadow: Colors.black.withValues(alpha: 0.32),
        scrim: Colors.black.withValues(alpha: 0.58),
      );
    }

    return baseColorScheme.copyWith(
      primary: const Color(0xFF458588),
      onPrimary: const Color(0xFFFBF1C7),
      secondary: const Color(0xFF689D6A),
      onSecondary: const Color(0xFFFBF1C7),
      tertiary: const Color(0xFFD79921),
      onTertiary: const Color(0xFF3C3836),
      error: const Color(0xFFCC241D),
      onError: const Color(0xFFFBF1C7),
      surface: const Color(0xFFF2E5BC),
      surfaceContainerLowest: const Color(0xFFFBF1C7),
      surfaceContainerLow: const Color(0xFFF2E5BC),
      surfaceContainer: const Color(0xFFEBDBB2),
      surfaceContainerHigh: const Color(0xFFE3D4A8),
      surfaceContainerHighest: const Color(0xFFD5C4A1),
      onSurface: const Color(0xFF3C3836),
      onSurfaceVariant: const Color(0xFF665C54),
      outline: const Color(0xFFA89984),
      outlineVariant: const Color(0xFFD5C4A1),
      shadow: Colors.black.withValues(alpha: 0.12),
      scrim: Colors.black.withValues(alpha: 0.45),
    );
  }

  static ColorScheme _everforrestColorScheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final baseColorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF7FBBB3),
      brightness: brightness,
    );

    if (isDark) {
      return baseColorScheme.copyWith(
        primary: const Color(0xFF7FBBB3),
        onPrimary: const Color(0xFF2D353B),
        secondary: const Color(0xFFA7C080),
        onSecondary: const Color(0xFF2D353B),
        tertiary: const Color(0xFFDBBC7F),
        onTertiary: const Color(0xFF2D353B),
        error: const Color(0xFFE67E80),
        onError: const Color(0xFF2D353B),
        surface: const Color(0xFF2D353B),
        surfaceContainerLowest: const Color(0xFF232A2E),
        surfaceContainerLow: const Color(0xFF2D353B),
        surfaceContainer: const Color(0xFF343F44),
        surfaceContainerHigh: const Color(0xFF3D484D),
        surfaceContainerHighest: const Color(0xFF475258),
        onSurface: const Color(0xFFD3C6AA),
        onSurfaceVariant: const Color(0xFF9DA9A0),
        outline: const Color(0xFF5C6A72),
        outlineVariant: const Color(0xFF4F585E),
        shadow: Colors.black.withValues(alpha: 0.30),
        scrim: Colors.black.withValues(alpha: 0.55),
      );
    }

    return baseColorScheme.copyWith(
      primary: const Color(0xFF3A94C5),
      onPrimary: const Color(0xFFFFFBEF),
      secondary: const Color(0xFF8DA101),
      onSecondary: const Color(0xFFFFFBEF),
      tertiary: const Color(0xFFDFA000),
      onTertiary: const Color(0xFFFFFBEF),
      error: const Color(0xFFF85552),
      onError: const Color(0xFFFFFBEF),
      surface: const Color(0xFFF8F5E4),
      surfaceContainerLowest: const Color(0xFFFFFBEF),
      surfaceContainerLow: const Color(0xFFF8F5E4),
      surfaceContainer: const Color(0xFFF2EFDF),
      surfaceContainerHigh: const Color(0xFFEDEADA),
      surfaceContainerHighest: const Color(0xFFE8E5D5),
      onSurface: const Color(0xFF5C6A72),
      onSurfaceVariant: const Color(0xFF708089),
      outline: const Color(0xFFA6B0A0),
      outlineVariant: const Color(0xFFD3C6AA),
      shadow: Colors.black.withValues(alpha: 0.10),
      scrim: Colors.black.withValues(alpha: 0.42),
    );
  }

  static ColorScheme _catppuccinAColorScheme(Brightness brightness) {
    if (brightness == Brightness.dark) {
      return _catppuccinDarkColorScheme(
        seedColor: const Color(0xFF8CAAEE),
        primary: const Color(0xFF8CAAEE),
        secondary: const Color(0xFF81C8BE),
        tertiary: const Color(0xFFE5C890),
        error: const Color(0xFFE78284),
        surface: const Color(0xFF303446),
        surfaceContainerLowest: const Color(0xFF232634),
        surfaceContainerLow: const Color(0xFF303446),
        surfaceContainer: const Color(0xFF414559),
        surfaceContainerHigh: const Color(0xFF51576D),
        surfaceContainerHighest: const Color(0xFF626880),
        onSurface: const Color(0xFFC6D0F5),
        onSurfaceVariant: const Color(0xFFA5ADCE),
        outline: const Color(0xFF737994),
        outlineVariant: const Color(0xFF51576D),
      );
    }

    return _catppuccinLightColorScheme(
      seedColor: const Color(0xFF1E66F5),
      primary: const Color(0xFF1E66F5),
      secondary: const Color(0xFF179299),
      tertiary: const Color(0xFFDF8E1D),
      error: const Color(0xFFD20F39),
    );
  }

  static ColorScheme _catppuccinBColorScheme(Brightness brightness) {
    if (brightness == Brightness.dark) {
      return _catppuccinDarkColorScheme(
        seedColor: const Color(0xFF8AADF4),
        primary: const Color(0xFF8AADF4),
        secondary: const Color(0xFF8BD5CA),
        tertiary: const Color(0xFFEED49F),
        error: const Color(0xFFED8796),
        surface: const Color(0xFF24273A),
        surfaceContainerLowest: const Color(0xFF181926),
        surfaceContainerLow: const Color(0xFF24273A),
        surfaceContainer: const Color(0xFF363A4F),
        surfaceContainerHigh: const Color(0xFF494D64),
        surfaceContainerHighest: const Color(0xFF5B6078),
        onSurface: const Color(0xFFCAD3F5),
        onSurfaceVariant: const Color(0xFFA5ADCB),
        outline: const Color(0xFF6E738D),
        outlineVariant: const Color(0xFF494D64),
      );
    }

    return _catppuccinLightColorScheme(
      seedColor: const Color(0xFF8839EF),
      primary: const Color(0xFF8839EF),
      secondary: const Color(0xFF7287FD),
      tertiary: const Color(0xFFFE640B),
      error: const Color(0xFFD20F39),
    );
  }

  static ColorScheme _catppuccinCColorScheme(Brightness brightness) {
    if (brightness == Brightness.dark) {
      return _catppuccinDarkColorScheme(
        seedColor: const Color(0xFF89B4FA),
        primary: const Color(0xFF89B4FA),
        secondary: const Color(0xFF94E2D5),
        tertiary: const Color(0xFFFAB387),
        error: const Color(0xFFF38BA8),
        surface: const Color(0xFF1E1E2E),
        surfaceContainerLowest: const Color(0xFF11111B),
        surfaceContainerLow: const Color(0xFF1E1E2E),
        surfaceContainer: const Color(0xFF313244),
        surfaceContainerHigh: const Color(0xFF45475A),
        surfaceContainerHighest: const Color(0xFF585B70),
        onSurface: const Color(0xFFCDD6F4),
        onSurfaceVariant: const Color(0xFFA6ADC8),
        outline: const Color(0xFF7F849C),
        outlineVariant: const Color(0xFF45475A),
      );
    }

    return _catppuccinLightColorScheme(
      seedColor: const Color(0xFFFE640B),
      primary: const Color(0xFFFE640B),
      secondary: const Color(0xFF40A02B),
      tertiary: const Color(0xFF1E66F5),
      error: const Color(0xFFD20F39),
    );
  }

  static ColorScheme _catppuccinMochaColorScheme(Brightness brightness) {
    if (brightness == Brightness.dark) {
      return _catppuccinDarkColorScheme(
        seedColor: const Color(0xFFCBA6F7),
        primary: const Color(0xFFCBA6F7),
        secondary: const Color(0xFF89B4FA),
        tertiary: const Color(0xFFF9E2AF),
        error: const Color(0xFFF38BA8),
        surface: const Color(0xFF1E1E2E),
        surfaceContainerLowest: const Color(0xFF11111B),
        surfaceContainerLow: const Color(0xFF1E1E2E),
        surfaceContainer: const Color(0xFF313244),
        surfaceContainerHigh: const Color(0xFF45475A),
        surfaceContainerHighest: const Color(0xFF585B70),
        onSurface: const Color(0xFFCDD6F4),
        onSurfaceVariant: const Color(0xFFA6ADC8),
        outline: const Color(0xFF7F849C),
        outlineVariant: const Color(0xFF45475A),
      );
    }

    return _catppuccinLightColorScheme(
      seedColor: const Color(0xFF8839EF),
      primary: const Color(0xFF8839EF),
      secondary: const Color(0xFF1E66F5),
      tertiary: const Color(0xFFDF8E1D),
      error: const Color(0xFFD20F39),
    );
  }

  static ColorScheme _nordColorScheme(Brightness brightness) {
    if (brightness == Brightness.dark) {
      return _themeDarkColorScheme(
        seedColor: const Color(0xFF88C0D0),
        primary: const Color(0xFF88C0D0),
        onPrimary: const Color(0xFF2E3440),
        secondary: const Color(0xFF81A1C1),
        onSecondary: const Color(0xFF2E3440),
        tertiary: const Color(0xFFEBCB8B),
        onTertiary: const Color(0xFF2E3440),
        error: const Color(0xFFBF616A),
        onError: const Color(0xFF2E3440),
        surface: const Color(0xFF3B4252),
        surfaceContainerLowest: const Color(0xFF2E3440),
        surfaceContainerLow: const Color(0xFF3B4252),
        surfaceContainer: const Color(0xFF434C5E),
        surfaceContainerHigh: const Color(0xFF4C566A),
        surfaceContainerHighest: const Color(0xFF616E88),
        onSurface: const Color(0xFFD8DEE9),
        onSurfaceVariant: const Color(0xFFBFC7D5),
        outline: const Color(0xFF5E81AC),
        outlineVariant: const Color(0xFF4C566A),
      );
    }

    return _themeLightColorScheme(
      seedColor: const Color(0xFF5E81AC),
      primary: const Color(0xFF5E81AC),
      onPrimary: const Color(0xFFF8FBFF),
      secondary: const Color(0xFF81A1C1),
      onSecondary: const Color(0xFF2E3440),
      tertiary: const Color(0xFFB48EAD),
      onTertiary: const Color(0xFFF8FBFF),
      error: const Color(0xFFBF616A),
      onError: const Color(0xFFF8FBFF),
      surface: const Color(0xFFECEFF4),
      surfaceContainerLowest: const Color(0xFFF5F7FA),
      surfaceContainerLow: const Color(0xFFECEFF4),
      surfaceContainer: const Color(0xFFE5E9F0),
      surfaceContainerHigh: const Color(0xFFD8DEE9),
      surfaceContainerHighest: const Color(0xFFC9D0DD),
      onSurface: const Color(0xFF2E3440),
      onSurfaceVariant: const Color(0xFF4C566A),
      outline: const Color(0xFF5E81AC),
      outlineVariant: const Color(0xFFD8DEE9),
    );
  }

  static ColorScheme _kanagowaColorScheme(Brightness brightness) {
    if (brightness == Brightness.dark) {
      return _themeDarkColorScheme(
        seedColor: const Color(0xFF7E9CD8),
        primary: const Color(0xFF7E9CD8),
        onPrimary: const Color(0xFF1F1F28),
        secondary: const Color(0xFF98BB6C),
        onSecondary: const Color(0xFF1F1F28),
        tertiary: const Color(0xFFE6C384),
        onTertiary: const Color(0xFF1F1F28),
        error: const Color(0xFFC34043),
        onError: const Color(0xFF1F1F28),
        surface: const Color(0xFF2A2A37),
        surfaceContainerLowest: const Color(0xFF1F1F28),
        surfaceContainerLow: const Color(0xFF2A2A37),
        surfaceContainer: const Color(0xFF363646),
        surfaceContainerHigh: const Color(0xFF4A4A5A),
        surfaceContainerHighest: const Color(0xFF54546D),
        onSurface: const Color(0xFFDCD7BA),
        onSurfaceVariant: const Color(0xFFC8C093),
        outline: const Color(0xFF727169),
        outlineVariant: const Color(0xFF4A4A5A),
      );
    }

    return _themeLightColorScheme(
      seedColor: const Color(0xFF4D699B),
      primary: const Color(0xFF4D699B),
      onPrimary: const Color(0xFFF2ECBC),
      secondary: const Color(0xFF6F894E),
      onSecondary: const Color(0xFFF2ECBC),
      tertiary: const Color(0xFFC79C4E),
      onTertiary: const Color(0xFF3B3228),
      error: const Color(0xFFC34043),
      onError: const Color(0xFFF2ECBC),
      surface: const Color(0xFFF4EFD2),
      surfaceContainerLowest: const Color(0xFFF8F4DC),
      surfaceContainerLow: const Color(0xFFF4EFD2),
      surfaceContainer: const Color(0xFFEDE3C9),
      surfaceContainerHigh: const Color(0xFFE2D6B6),
      surfaceContainerHighest: const Color(0xFFD1C7AA),
      onSurface: const Color(0xFF54546D),
      onSurfaceVariant: const Color(0xFF716E61),
      outline: const Color(0xFF8A867A),
      outlineVariant: const Color(0xFFD1C7AA),
    );
  }

  static ColorScheme _draculaColorScheme(Brightness brightness) {
    if (brightness == Brightness.dark) {
      return _themeDarkColorScheme(
        seedColor: const Color(0xFFBD93F9),
        primary: const Color(0xFFBD93F9),
        onPrimary: const Color(0xFF282A36),
        secondary: const Color(0xFF8BE9FD),
        onSecondary: const Color(0xFF282A36),
        tertiary: const Color(0xFFF1FA8C),
        onTertiary: const Color(0xFF282A36),
        error: const Color(0xFFFF5555),
        onError: const Color(0xFF282A36),
        surface: const Color(0xFF303341),
        surfaceContainerLowest: const Color(0xFF282A36),
        surfaceContainerLow: const Color(0xFF303341),
        surfaceContainer: const Color(0xFF44475A),
        surfaceContainerHigh: const Color(0xFF6272A4),
        surfaceContainerHighest: const Color(0xFF7B87B9),
        onSurface: const Color(0xFFF8F8F2),
        onSurfaceVariant: const Color(0xFFCBD0E3),
        outline: const Color(0xFF6272A4),
        outlineVariant: const Color(0xFF44475A),
      );
    }

    return _themeLightColorScheme(
      seedColor: const Color(0xFF9580FF),
      primary: const Color(0xFF9580FF),
      onPrimary: const Color(0xFFFFFFFF),
      secondary: const Color(0xFF5BC0EB),
      onSecondary: const Color(0xFFFFFFFF),
      tertiary: const Color(0xFFD9CF7A),
      onTertiary: const Color(0xFF3B3557),
      error: const Color(0xFFD95B6A),
      onError: const Color(0xFFFFFFFF),
      surface: const Color(0xFFF7F7FB),
      surfaceContainerLowest: const Color(0xFFFCFCFE),
      surfaceContainerLow: const Color(0xFFF7F7FB),
      surfaceContainer: const Color(0xFFECECF4),
      surfaceContainerHigh: const Color(0xFFDBD9EA),
      surfaceContainerHighest: const Color(0xFFC9C7DE),
      onSurface: const Color(0xFF2F3142),
      onSurfaceVariant: const Color(0xFF555A77),
      outline: const Color(0xFF8E92B3),
      outlineVariant: const Color(0xFFDBD9EA),
    );
  }

  static ColorScheme _solarizedColorScheme(Brightness brightness) {
    if (brightness == Brightness.dark) {
      return _themeDarkColorScheme(
        seedColor: const Color(0xFF268BD2),
        primary: const Color(0xFF268BD2),
        onPrimary: const Color(0xFF002B36),
        secondary: const Color(0xFF2AA198),
        onSecondary: const Color(0xFF002B36),
        tertiary: const Color(0xFFB58900),
        onTertiary: const Color(0xFF002B36),
        error: const Color(0xFFDC322F),
        onError: const Color(0xFF002B36),
        surface: const Color(0xFF073642),
        surfaceContainerLowest: const Color(0xFF002B36),
        surfaceContainerLow: const Color(0xFF073642),
        surfaceContainer: const Color(0xFF0A4352),
        surfaceContainerHigh: const Color(0xFF335D66),
        surfaceContainerHighest: const Color(0xFF586E75),
        onSurface: const Color(0xFF93A1A1),
        onSurfaceVariant: const Color(0xFF839496),
        outline: const Color(0xFF657B83),
        outlineVariant: const Color(0xFF335D66),
      );
    }

    return _themeLightColorScheme(
      seedColor: const Color(0xFF268BD2),
      primary: const Color(0xFF268BD2),
      onPrimary: const Color(0xFFFDF6E3),
      secondary: const Color(0xFF2AA198),
      onSecondary: const Color(0xFFFDF6E3),
      tertiary: const Color(0xFFB58900),
      onTertiary: const Color(0xFFFDF6E3),
      error: const Color(0xFFDC322F),
      onError: const Color(0xFFFDF6E3),
      surface: const Color(0xFFF5EFD8),
      surfaceContainerLowest: const Color(0xFFFDF6E3),
      surfaceContainerLow: const Color(0xFFF5EFD8),
      surfaceContainer: const Color(0xFFEEE8D5),
      surfaceContainerHigh: const Color(0xFFE7E1CE),
      surfaceContainerHighest: const Color(0xFFDFD8C1),
      onSurface: const Color(0xFF657B83),
      onSurfaceVariant: const Color(0xFF586E75),
      outline: const Color(0xFF93A1A1),
      outlineVariant: const Color(0xFFE7E1CE),
    );
  }

  static ColorScheme _monokaiColorScheme(Brightness brightness) {
    if (brightness == Brightness.dark) {
      return _themeDarkColorScheme(
        seedColor: const Color(0xFFA6E22E),
        primary: const Color(0xFFA6E22E),
        onPrimary: const Color(0xFF272822),
        secondary: const Color(0xFF66D9EF),
        onSecondary: const Color(0xFF272822),
        tertiary: const Color(0xFFF4BF75),
        onTertiary: const Color(0xFF272822),
        error: const Color(0xFFF92672),
        onError: const Color(0xFF272822),
        surface: const Color(0xFF383830),
        surfaceContainerLowest: const Color(0xFF272822),
        surfaceContainerLow: const Color(0xFF383830),
        surfaceContainer: const Color(0xFF49483E),
        surfaceContainerHigh: const Color(0xFF5B5A4C),
        surfaceContainerHighest: const Color(0xFF75715E),
        onSurface: const Color(0xFFF8F8F2),
        onSurfaceVariant: const Color(0xFFCFCFC2),
        outline: const Color(0xFF75715E),
        outlineVariant: const Color(0xFF49483E),
      );
    }

    return _themeLightColorScheme(
      seedColor: const Color(0xFF3FA9BE),
      primary: const Color(0xFF3FA9BE),
      onPrimary: const Color(0xFFF8F8F2),
      secondary: const Color(0xFF7D9F28),
      onSecondary: const Color(0xFFF8F8F2),
      tertiary: const Color(0xFFC28C44),
      onTertiary: const Color(0xFFF8F8F2),
      error: const Color(0xFFC44D75),
      onError: const Color(0xFFF8F8F2),
      surface: const Color(0xFFF2F2E7),
      surfaceContainerLowest: const Color(0xFFF8F8F2),
      surfaceContainerLow: const Color(0xFFF2F2E7),
      surfaceContainer: const Color(0xFFE8E8DD),
      surfaceContainerHigh: const Color(0xFFDDDDD1),
      surfaceContainerHighest: const Color(0xFFD0D0C1),
      onSurface: const Color(0xFF3B3A32),
      onSurfaceVariant: const Color(0xFF666457),
      outline: const Color(0xFFA8A594),
      outlineVariant: const Color(0xFFDDDDD1),
    );
  }

  static ColorScheme _tokyoNightColorScheme(Brightness brightness) {
    if (brightness == Brightness.dark) {
      return _themeDarkColorScheme(
        seedColor: const Color(0xFF7AA2F7),
        primary: const Color(0xFF7AA2F7),
        onPrimary: const Color(0xFF1A1B26),
        secondary: const Color(0xFF9ECE6A),
        onSecondary: const Color(0xFF1A1B26),
        tertiary: const Color(0xFFE0AF68),
        onTertiary: const Color(0xFF1A1B26),
        error: const Color(0xFFF7768E),
        onError: const Color(0xFF1A1B26),
        surface: const Color(0xFF24283B),
        surfaceContainerLowest: const Color(0xFF1A1B26),
        surfaceContainerLow: const Color(0xFF24283B),
        surfaceContainer: const Color(0xFF2F354F),
        surfaceContainerHigh: const Color(0xFF414868),
        surfaceContainerHighest: const Color(0xFF565F89),
        onSurface: const Color(0xFFC0CAF5),
        onSurfaceVariant: const Color(0xFFA9B1D6),
        outline: const Color(0xFF565F89),
        outlineVariant: const Color(0xFF414868),
      );
    }

    return _themeLightColorScheme(
      seedColor: const Color(0xFF3760BF),
      primary: const Color(0xFF3760BF),
      onPrimary: const Color(0xFFF7F8FC),
      secondary: const Color(0xFF587539),
      onSecondary: const Color(0xFFF7F8FC),
      tertiary: const Color(0xFF8C6A2D),
      onTertiary: const Color(0xFFF7F8FC),
      error: const Color(0xFFC53B53),
      onError: const Color(0xFFF7F8FC),
      surface: const Color(0xFFE1E2E7),
      surfaceContainerLowest: const Color(0xFFEEF0F5),
      surfaceContainerLow: const Color(0xFFE1E2E7),
      surfaceContainer: const Color(0xFFD5D6DB),
      surfaceContainerHigh: const Color(0xFFC6C8D1),
      surfaceContainerHighest: const Color(0xFFB7BAC5),
      onSurface: const Color(0xFF343B58),
      onSurfaceVariant: const Color(0xFF565F89),
      outline: const Color(0xFF7A88B8),
      outlineVariant: const Color(0xFFC6C8D1),
    );
  }

  static ColorScheme _zenburnColorScheme(Brightness brightness) {
    if (brightness == Brightness.dark) {
      return _themeDarkColorScheme(
        seedColor: const Color(0xFF8CD0D3),
        primary: const Color(0xFF8CD0D3),
        onPrimary: const Color(0xFF3F3F3F),
        secondary: const Color(0xFF9FC59F),
        onSecondary: const Color(0xFF3F3F3F),
        tertiary: const Color(0xFFF0DFAF),
        onTertiary: const Color(0xFF3F3F3F),
        error: const Color(0xFFCC9393),
        onError: const Color(0xFF3F3F3F),
        surface: const Color(0xFF4F4F4F),
        surfaceContainerLowest: const Color(0xFF3F3F3F),
        surfaceContainerLow: const Color(0xFF4F4F4F),
        surfaceContainer: const Color(0xFF5F5F5F),
        surfaceContainerHigh: const Color(0xFF6F6F6F),
        surfaceContainerHighest: const Color(0xFF7F7F7F),
        onSurface: const Color(0xFFDCDCCC),
        onSurfaceVariant: const Color(0xFFBFBFA5),
        outline: const Color(0xFF8F8F7F),
        outlineVariant: const Color(0xFF6F6F6F),
      );
    }

    return _themeLightColorScheme(
      seedColor: const Color(0xFF5A8A8A),
      primary: const Color(0xFF5A8A8A),
      onPrimary: const Color(0xFFF5F3E8),
      secondary: const Color(0xFF6E8F6E),
      onSecondary: const Color(0xFFF5F3E8),
      tertiary: const Color(0xFFBEAB7A),
      onTertiary: const Color(0xFF4A3F2D),
      error: const Color(0xFFA96F6F),
      onError: const Color(0xFFF5F3E8),
      surface: const Color(0xFFEFEBD9),
      surfaceContainerLowest: const Color(0xFFF9F7EE),
      surfaceContainerLow: const Color(0xFFF5F3E8),
      surfaceContainer: const Color(0xFFEDE8D5),
      surfaceContainerHigh: const Color(0xFFE1DBC3),
      surfaceContainerHighest: const Color(0xFFD3CCB3),
      onSurface: const Color(0xFF4E4E3F),
      onSurfaceVariant: const Color(0xFF6D6D5A),
      outline: const Color(0xFF9A997D),
      outlineVariant: const Color(0xFFE1DBC3),
    );
  }

  static ColorScheme _catppuccinLightColorScheme({
    required Color seedColor,
    required Color primary,
    required Color secondary,
    required Color tertiary,
    required Color error,
  }) {
    final baseColorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.light,
    );
    return baseColorScheme.copyWith(
      primary: primary,
      onPrimary: const Color(0xFFEFF1F5),
      secondary: secondary,
      onSecondary: const Color(0xFFEFF1F5),
      tertiary: tertiary,
      onTertiary: const Color(0xFFEFF1F5),
      error: error,
      onError: const Color(0xFFEFF1F5),
      surface: const Color(0xFFF2F5FA),
      surfaceContainerLowest: const Color(0xFFEFF1F5),
      surfaceContainerLow: const Color(0xFFE6E9EF),
      surfaceContainer: const Color(0xFFDCE0E8),
      surfaceContainerHigh: const Color(0xFFCCD0DA),
      surfaceContainerHighest: const Color(0xFFBCC0CC),
      onSurface: const Color(0xFF4C4F69),
      onSurfaceVariant: const Color(0xFF6C6F85),
      outline: const Color(0xFF8C8FA1),
      outlineVariant: const Color(0xFFCCD0DA),
      shadow: Colors.black.withValues(alpha: 0.10),
      scrim: Colors.black.withValues(alpha: 0.42),
    );
  }

  static ColorScheme _catppuccinDarkColorScheme({
    required Color seedColor,
    required Color primary,
    required Color secondary,
    required Color tertiary,
    required Color error,
    required Color surface,
    required Color surfaceContainerLowest,
    required Color surfaceContainerLow,
    required Color surfaceContainer,
    required Color surfaceContainerHigh,
    required Color surfaceContainerHighest,
    required Color onSurface,
    required Color onSurfaceVariant,
    required Color outline,
    required Color outlineVariant,
  }) {
    final baseColorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.dark,
    );
    return baseColorScheme.copyWith(
      primary: primary,
      onPrimary: surface,
      secondary: secondary,
      onSecondary: surface,
      tertiary: tertiary,
      onTertiary: surface,
      error: error,
      onError: surface,
      surface: surface,
      surfaceContainerLowest: surfaceContainerLowest,
      surfaceContainerLow: surfaceContainerLow,
      surfaceContainer: surfaceContainer,
      surfaceContainerHigh: surfaceContainerHigh,
      surfaceContainerHighest: surfaceContainerHighest,
      onSurface: onSurface,
      onSurfaceVariant: onSurfaceVariant,
      outline: outline,
      outlineVariant: outlineVariant,
      shadow: Colors.black.withValues(alpha: 0.30),
      scrim: Colors.black.withValues(alpha: 0.55),
    );
  }

  static ColorScheme _themeLightColorScheme({
    required Color seedColor,
    required Color primary,
    required Color onPrimary,
    required Color secondary,
    required Color onSecondary,
    required Color tertiary,
    required Color onTertiary,
    required Color error,
    required Color onError,
    required Color surface,
    required Color surfaceContainerLowest,
    required Color surfaceContainerLow,
    required Color surfaceContainer,
    required Color surfaceContainerHigh,
    required Color surfaceContainerHighest,
    required Color onSurface,
    required Color onSurfaceVariant,
    required Color outline,
    required Color outlineVariant,
  }) {
    final baseColorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.light,
    );
    return baseColorScheme.copyWith(
      primary: primary,
      onPrimary: onPrimary,
      secondary: secondary,
      onSecondary: onSecondary,
      tertiary: tertiary,
      onTertiary: onTertiary,
      error: error,
      onError: onError,
      surface: surface,
      surfaceContainerLowest: surfaceContainerLowest,
      surfaceContainerLow: surfaceContainerLow,
      surfaceContainer: surfaceContainer,
      surfaceContainerHigh: surfaceContainerHigh,
      surfaceContainerHighest: surfaceContainerHighest,
      onSurface: onSurface,
      onSurfaceVariant: onSurfaceVariant,
      outline: outline,
      outlineVariant: outlineVariant,
      shadow: Colors.black.withValues(alpha: 0.10),
      scrim: Colors.black.withValues(alpha: 0.42),
    );
  }

  static ColorScheme _themeDarkColorScheme({
    required Color seedColor,
    required Color primary,
    required Color onPrimary,
    required Color secondary,
    required Color onSecondary,
    required Color tertiary,
    required Color onTertiary,
    required Color error,
    required Color onError,
    required Color surface,
    required Color surfaceContainerLowest,
    required Color surfaceContainerLow,
    required Color surfaceContainer,
    required Color surfaceContainerHigh,
    required Color surfaceContainerHighest,
    required Color onSurface,
    required Color onSurfaceVariant,
    required Color outline,
    required Color outlineVariant,
  }) {
    final baseColorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.dark,
    );
    return baseColorScheme.copyWith(
      primary: primary,
      onPrimary: onPrimary,
      secondary: secondary,
      onSecondary: onSecondary,
      tertiary: tertiary,
      onTertiary: onTertiary,
      error: error,
      onError: onError,
      surface: surface,
      surfaceContainerLowest: surfaceContainerLowest,
      surfaceContainerLow: surfaceContainerLow,
      surfaceContainer: surfaceContainer,
      surfaceContainerHigh: surfaceContainerHigh,
      surfaceContainerHighest: surfaceContainerHighest,
      onSurface: onSurface,
      onSurfaceVariant: onSurfaceVariant,
      outline: outline,
      outlineVariant: outlineVariant,
      shadow: Colors.black.withValues(alpha: 0.30),
      scrim: Colors.black.withValues(alpha: 0.55),
    );
  }
}
