import 'package:cohortz/shared/theme/models/theme_preset.dart';
import 'package:cohortz/shared/theme/tokens/app_shape_tokens.dart';
import 'package:cohortz/shared/theme/tokens/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'gruvbox theme uses square shape tokens',
    () {
      final darkGruvbox = AppTheme.darkFor(ThemePreset.gruvbox);
      final shapes = darkGruvbox.extension<AppShapeTokens>();

      expect(shapes, isNotNull);
      expect(shapes!.cardRadius, 0);
      expect(shapes.dialogRadius, 0);
      expect(shapes.elementRadius, 0);

      final cardShape = darkGruvbox.cardTheme.shape as RoundedRectangleBorder;
      final borderRadius = cardShape.borderRadius as BorderRadius;
      expect(borderRadius.topLeft.x, 0);

      expect(darkGruvbox.colorScheme.surface, const Color(0xFF282828));
      expect(darkGruvbox.colorScheme.onSurface, const Color(0xFFEBDBB2));
    },
    skip: 'google_fonts runtime loading is not stable in headless test env',
  );

  test(
    'cohrtz theme keeps rounded shape tokens',
    () {
      final lightCohrtz = AppTheme.lightFor(ThemePreset.cohrtz);
      final shapes = lightCohrtz.extension<AppShapeTokens>();

      expect(shapes, isNotNull);
      expect(shapes!.cardRadius, 32);
      expect(shapes.dialogRadius, 32);
      expect(shapes.elementRadius, 16);
    },
    skip: 'google_fonts runtime loading is not stable in headless test env',
  );
}
