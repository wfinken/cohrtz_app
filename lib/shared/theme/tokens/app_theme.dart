import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';
import 'app_semantic_colors.dart';
import 'layout_constants.dart';

/// Centralized theme configuration for the Cohrtz app.
///
/// Provides both light and dark theme data derived from a Material 3 seed
/// color.
class AppTheme {
  AppTheme._();

  static const Color seedColor = AppColors.accent;

  /// Corner radius used throughout the app for cards (matches mockup rounded-2xl)
  static const double cardRadius = LayoutConstants.kDefaultRadius;

  /// Corner radius used for dialogs
  static const double dialogRadius = LayoutConstants.kDefaultRadius;

  /// Corner radius for buttons and inputs
  static const double elementRadius = 16.0;

  /// Base text theme using Inter font (Standard for modern UIs)
  static TextTheme get _baseTextTheme => GoogleFonts.interTextTheme();

  static ThemeData _theme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final baseColorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
    );
    final colorScheme = baseColorScheme.copyWith(
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

    final baseTheme = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: isDark
          ? AppColors.darkPage
          : AppColors.lightPage,
      canvasColor: colorScheme.surface,
      dividerColor: colorScheme.outlineVariant,
      hintColor: AppColors.slate500,
      splashFactory: InkRipple.splashFactory,
    );
    final textTheme = _baseTextTheme
        .copyWith(
          titleLarge: GoogleFonts.inter(
            color: colorScheme.onSurface,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
          titleMedium: GoogleFonts.inter(
            color: colorScheme.onSurface,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          bodyLarge: GoogleFonts.inter(
            color: colorScheme.onSurface,
            fontSize: 16,
          ),
          bodyMedium: GoogleFonts.inter(
            color: colorScheme.onSurface,
            fontSize: 14,
          ),
          bodySmall: GoogleFonts.inter(
            color: colorScheme.onSurfaceVariant,
            fontSize: 12,
          ),
          labelSmall: GoogleFonts.inter(
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
      extensions: <ThemeExtension<dynamic>>[
        isDark ? AppSemanticColors.dark() : AppSemanticColors.light(),
      ],
      textTheme: textTheme,
      iconTheme: IconThemeData(color: colorScheme.onSurfaceVariant),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colorScheme.primary,
        linearTrackColor: colorScheme.surfaceContainerHigh,
        linearMinHeight: 8,
        borderRadius: BorderRadius.circular(999),
      ),

      cardTheme: CardThemeData(
        color: colorScheme.surface,
        elevation: 0.5,
        shadowColor: colorScheme.shadow,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
          side: BorderSide(color: colorScheme.outlineVariant, width: 1),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark
            ? AppColors.slate900.withValues(alpha: 0.50)
            : colorScheme.surfaceContainerLow,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        hintStyle: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(elementRadius),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(elementRadius),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(elementRadius),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(elementRadius),
          borderSide: BorderSide(color: colorScheme.error),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style:
            ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shadowColor: colorScheme.primary.withValues(alpha: 0.35),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(elementRadius),
              ),
              textStyle: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
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
            borderRadius: BorderRadius.circular(elementRadius),
          ),
          textStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
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
        titleTextStyle: GoogleFonts.inter(
          color: colorScheme.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
        contentTextStyle: GoogleFonts.inter(
          color: colorScheme.onSurfaceVariant,
          fontSize: 15,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(dialogRadius),
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
        titleTextStyle: GoogleFonts.inter(
          color: colorScheme.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: colorScheme.surfaceContainerHigh,
        shadowColor: colorScheme.shadow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
    );
  }

  /// Light theme data.
  static ThemeData get light => _theme(Brightness.light);

  /// Dark theme data.
  static ThemeData get dark => _theme(Brightness.dark);
}
