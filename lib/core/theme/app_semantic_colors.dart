import 'package:flutter/material.dart';

@immutable
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  const AppSemanticColors({
    required this.success,
    required this.warning,
    required this.danger,
    required this.info,
    required this.accentMuted,
    required this.skeletonBase,
    required this.skeletonHighlight,
  });

  final Color success;
  final Color warning;
  final Color danger;
  final Color info;
  final Color accentMuted;
  final Color skeletonBase;
  final Color skeletonHighlight;

  @override
  AppSemanticColors copyWith({
    Color? success,
    Color? warning,
    Color? danger,
    Color? info,
    Color? accentMuted,
    Color? skeletonBase,
    Color? skeletonHighlight,
  }) {
    return AppSemanticColors(
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      info: info ?? this.info,
      accentMuted: accentMuted ?? this.accentMuted,
      skeletonBase: skeletonBase ?? this.skeletonBase,
      skeletonHighlight: skeletonHighlight ?? this.skeletonHighlight,
    );
  }

  @override
  AppSemanticColors lerp(ThemeExtension<AppSemanticColors>? other, double t) {
    if (other is! AppSemanticColors) return this;
    return AppSemanticColors(
      success: Color.lerp(success, other.success, t) ?? success,
      warning: Color.lerp(warning, other.warning, t) ?? warning,
      danger: Color.lerp(danger, other.danger, t) ?? danger,
      info: Color.lerp(info, other.info, t) ?? info,
      accentMuted: Color.lerp(accentMuted, other.accentMuted, t) ?? accentMuted,
      skeletonBase:
          Color.lerp(skeletonBase, other.skeletonBase, t) ?? skeletonBase,
      skeletonHighlight:
          Color.lerp(skeletonHighlight, other.skeletonHighlight, t) ??
          skeletonHighlight,
    );
  }

  static AppSemanticColors light() {
    return const AppSemanticColors(
      success: Color(0xFF059669),
      warning: Color(0xFFD97706),
      danger: Color(0xFFDC2626),
      info: Color(0xFF2563EB),
      accentMuted: Color(0xFFE0E7FF),
      skeletonBase: Color(0xFFE2E8F0),
      skeletonHighlight: Color(0xFFF1F5F9),
    );
  }

  static AppSemanticColors dark() {
    return const AppSemanticColors(
      success: Color(0xFF10B981),
      warning: Color(0xFFF59E0B),
      danger: Color(0xFFEF4444),
      info: Color(0xFF60A5FA),
      accentMuted: Color(0xFF312E81),
      skeletonBase: Color(0xFF27272A),
      skeletonHighlight: Color(0xFF3F3F46),
    );
  }
}
