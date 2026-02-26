import 'package:cohortz/shared/theme/models/theme_radius_preset.dart';
import 'package:flutter/material.dart';

enum AppShapePattern { uniform, diagonal }

@immutable
class AppShapeTokens extends ThemeExtension<AppShapeTokens> {
  const AppShapeTokens({
    required this.radiusXs,
    required this.radiusSm,
    required this.radiusMd,
    required this.radiusLg,
    required this.radiusXl,
    required this.cardRadius,
    required this.dialogRadius,
    required this.elementRadius,
    required this.menuRadius,
    this.pattern = AppShapePattern.uniform,
  });

  final double radiusXs;
  final double radiusSm;
  final double radiusMd;
  final double radiusLg;
  final double radiusXl;
  final double cardRadius;
  final double dialogRadius;
  final double elementRadius;
  final double menuRadius;
  final AppShapePattern pattern;

  static const AppShapeTokens rounded = AppShapeTokens(
    radiusXs: 4,
    radiusSm: 8,
    radiusMd: 12,
    radiusLg: 16,
    radiusXl: 20,
    cardRadius: 32,
    dialogRadius: 32,
    elementRadius: 16,
    menuRadius: 20,
  );

  static const AppShapeTokens soft = AppShapeTokens(
    radiusXs: 6,
    radiusSm: 10,
    radiusMd: 14,
    radiusLg: 18,
    radiusXl: 24,
    cardRadius: 36,
    dialogRadius: 36,
    elementRadius: 18,
    menuRadius: 22,
  );

  static const AppShapeTokens sharp = AppShapeTokens(
    radiusXs: 0,
    radiusSm: 0,
    radiusMd: 0,
    radiusLg: 0,
    radiusXl: 0,
    cardRadius: 0,
    dialogRadius: 0,
    elementRadius: 0,
    menuRadius: 0,
  );

  static const AppShapeTokens diagonal = AppShapeTokens(
    radiusXs: 3,
    radiusSm: 6,
    radiusMd: 10,
    radiusLg: 14,
    radiusXl: 18,
    cardRadius: 24,
    dialogRadius: 24,
    elementRadius: 12,
    menuRadius: 14,
    pattern: AppShapePattern.diagonal,
  );

  // Backward-compatible aliases for older callsites.
  static const AppShapeTokens cohrtz = rounded;
  static const AppShapeTokens gruvbox = sharp;
  static const AppShapeTokens everforrest = soft;

  static AppShapeTokens fromPreset(ThemeRadiusPreset preset) {
    switch (preset) {
      case ThemeRadiusPreset.rounded:
        return AppShapeTokens.rounded;
      case ThemeRadiusPreset.soft:
        return AppShapeTokens.soft;
      case ThemeRadiusPreset.sharp:
        return AppShapeTokens.sharp;
      case ThemeRadiusPreset.diagonal:
        return AppShapeTokens.diagonal;
    }
  }

  double resolveLegacy(double legacyRadius) {
    if (legacyRadius <= 4) return radiusXs;
    if (legacyRadius <= 8) return radiusSm;
    if (legacyRadius <= 12) return radiusMd;
    if (legacyRadius <= 16) return radiusLg;
    if (legacyRadius <= 20) return radiusXl;
    return cardRadius;
  }

  BorderRadius borderRadius(double radius) {
    final value = radius < 0 ? 0.0 : radius;
    switch (pattern) {
      case AppShapePattern.uniform:
        return BorderRadius.circular(value);
      case AppShapePattern.diagonal:
        return BorderRadius.only(
          topRight: Radius.circular(value),
          bottomLeft: Radius.circular(value),
        );
    }
  }

  BorderRadius resolveBorderRadius(double legacyRadius) {
    return borderRadius(resolveLegacy(legacyRadius));
  }

  @override
  AppShapeTokens copyWith({
    double? radiusXs,
    double? radiusSm,
    double? radiusMd,
    double? radiusLg,
    double? radiusXl,
    double? cardRadius,
    double? dialogRadius,
    double? elementRadius,
    double? menuRadius,
    AppShapePattern? pattern,
  }) {
    return AppShapeTokens(
      radiusXs: radiusXs ?? this.radiusXs,
      radiusSm: radiusSm ?? this.radiusSm,
      radiusMd: radiusMd ?? this.radiusMd,
      radiusLg: radiusLg ?? this.radiusLg,
      radiusXl: radiusXl ?? this.radiusXl,
      cardRadius: cardRadius ?? this.cardRadius,
      dialogRadius: dialogRadius ?? this.dialogRadius,
      elementRadius: elementRadius ?? this.elementRadius,
      menuRadius: menuRadius ?? this.menuRadius,
      pattern: pattern ?? this.pattern,
    );
  }

  @override
  AppShapeTokens lerp(ThemeExtension<AppShapeTokens>? other, double t) {
    if (other is! AppShapeTokens) return this;
    return AppShapeTokens(
      radiusXs: lerpDouble(radiusXs, other.radiusXs, t),
      radiusSm: lerpDouble(radiusSm, other.radiusSm, t),
      radiusMd: lerpDouble(radiusMd, other.radiusMd, t),
      radiusLg: lerpDouble(radiusLg, other.radiusLg, t),
      radiusXl: lerpDouble(radiusXl, other.radiusXl, t),
      cardRadius: lerpDouble(cardRadius, other.cardRadius, t),
      dialogRadius: lerpDouble(dialogRadius, other.dialogRadius, t),
      elementRadius: lerpDouble(elementRadius, other.elementRadius, t),
      menuRadius: lerpDouble(menuRadius, other.menuRadius, t),
      pattern: t < 0.5 ? pattern : other.pattern,
    );
  }

  static double lerpDouble(double a, double b, double t) => a + (b - a) * t;
}

AppShapeTokens appShapeTokensOf(BuildContext context) {
  return Theme.of(context).extension<AppShapeTokens>() ?? AppShapeTokens.cohrtz;
}

double resolveAppRadius(BuildContext context, double legacyRadius) {
  return appShapeTokensOf(context).resolveLegacy(legacyRadius);
}

extension AppShapeContextX on BuildContext {
  AppShapeTokens get appShapes => appShapeTokensOf(this);

  double appRadius([double legacyRadius = 12]) {
    return resolveAppRadius(this, legacyRadius);
  }

  Radius appRadiusValue([double legacyRadius = 12]) {
    return Radius.circular(appRadius(legacyRadius));
  }

  BorderRadius appBorderRadius([double legacyRadius = 12]) {
    return appShapes.resolveBorderRadius(legacyRadius);
  }
}
