import 'package:flutter/material.dart';
import 'dart:math' as math;

/// A button widget for adding a new group, featuring a dashed border.
///
/// Displays a 48x48 container with a dashed border and plus icon,
/// using theme colors exclusively.
class AddGroupButton extends StatefulWidget {
  final VoidCallback? onTap;

  const AddGroupButton({super.key, this.onTap});

  @override
  State<AddGroupButton> createState() => _AddGroupButtonState();
}

class _AddGroupButtonState extends State<AddGroupButton> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: SizedBox(
          height: 48,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Hover Indicator (Left Pill) - matches GroupButton behavior
              Positioned(
                left: 0,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.fastOutSlowIn,
                  width: 4,
                  height: _isHovering ? 12 : 0,
                  decoration: BoxDecoration(
                    color: colorScheme.onSurface,
                    borderRadius: const BorderRadius.horizontal(
                      right: Radius.circular(4),
                    ),
                  ),
                ),
              ),

              SizedBox(
                width: 48,
                height: 48,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  decoration: BoxDecoration(
                    color: _isHovering
                        ? colorScheme.primary.withValues(alpha: 0.05)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(_isHovering ? 12 : 24),
                  ),
                  child: TweenAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    tween: Tween<double>(
                      begin: 24.0,
                      end: _isHovering ? 12.0 : 24.0,
                    ),
                    builder: (context, value, child) {
                      return CustomPaint(
                        painter: _DashedBorderPainter(
                          color: colorScheme.primary,
                          dashWidth: 4,
                          dashSpace: 4,
                          strokeWidth: 2,
                          borderRadius: value,
                        ),
                        child: Center(
                          child: Icon(
                            Icons.add,
                            color: colorScheme.primary,
                            size: 24,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Custom painter for creating a dashed border effect.
class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double dashWidth;
  final double dashSpace;
  final double strokeWidth;
  final double borderRadius;

  _DashedBorderPainter({
    required this.color,
    this.dashWidth = 4,
    this.dashSpace = 4,
    this.strokeWidth = 2,
    this.borderRadius = 8,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final path = Path();

    path.addRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Radius.circular(borderRadius),
      ),
    );

    _drawDashedPath(canvas, path, paint);
  }

  void _drawDashedPath(Canvas canvas, Path path, Paint paint) {
    final pathMetrics = path.computeMetrics();

    for (final metric in pathMetrics) {
      double distance = 0;
      while (distance < metric.length) {
        final start = distance;
        final end = math.min(distance + dashWidth, metric.length);

        final extractPath = metric.extractPath(start, end);
        canvas.drawPath(extractPath, paint);

        distance = end + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.dashWidth != dashWidth ||
        oldDelegate.dashSpace != dashSpace ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.borderRadius != borderRadius;
  }
}
