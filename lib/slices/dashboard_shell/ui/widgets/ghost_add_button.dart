import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../../../shared/theme/tokens/app_shape_tokens.dart';

class GhostAddButton extends StatefulWidget {
  final String label;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final double? height;

  const GhostAddButton({
    super.key,
    required this.label,
    this.onTap,
    this.padding,
    this.margin,
    this.borderRadius = 12,
    this.height,
  });

  @override
  State<GhostAddButton> createState() => _GhostAddButtonState();
}

class _GhostAddButtonState extends State<GhostAddButton> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hintColor = theme.hintColor;
    final resolvedRadius = context.appRadius(widget.borderRadius);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: widget.height,
      margin: widget.margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(resolvedRadius),
        color: _isHovering
            ? colorScheme.onSurface.withValues(alpha: 0.05)
            : Colors.transparent,
      ),
      child: CustomPaint(
        painter: _DashedBorderPainter(
          color: _isHovering
              ? colorScheme.primary.withValues(alpha: 0.5)
              : hintColor.withValues(alpha: 0.3),
          dashWidth: 4,
          dashSpace: 4,
          strokeWidth: 1.5,
          borderRadius: resolvedRadius,
        ),
        child: MouseRegion(
          cursor: widget.onTap != null
              ? SystemMouseCursors.click
              : SystemMouseCursors.basic,
          onEnter: (_) => setState(() => _isHovering = true),
          onExit: (_) => setState(() => _isHovering = false),
          child: GestureDetector(
            onTap: widget.onTap,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding:
                  widget.padding ?? const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add,
                    color: _isHovering
                        ? colorScheme.primary
                        : hintColor.withValues(alpha: 0.6),
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      widget.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _isHovering
                            ? colorScheme.primary
                            : hintColor.withValues(alpha: 0.6),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

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
    this.strokeWidth = 1,
    this.borderRadius = 8,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.butt
      ..isAntiAlias = true;

    final inset = strokeWidth;
    final rect = Rect.fromLTWH(
      inset,
      inset,
      size.width - inset * 2,
      size.height - inset * 2,
    );

    final radius = math.min(borderRadius, rect.shortestSide / 2);
    final left = rect.left;
    final top = rect.top;
    final right = rect.right;
    final bottom = rect.bottom;

    final dashedSegments = <Path>[
      Path()
        ..moveTo(left + radius, top)
        ..lineTo(right - radius, top),
      Path()
        ..moveTo(right, top + radius)
        ..lineTo(right, bottom - radius),
      Path()
        ..moveTo(right - radius, bottom)
        ..lineTo(left + radius, bottom),
      Path()
        ..moveTo(left, bottom - radius)
        ..lineTo(left, top + radius),
    ];

    for (final path in dashedSegments) {
      for (final metric in path.computeMetrics()) {
        double distance = 0;
        while (distance < metric.length) {
          final start = distance;
          final end = math.min(distance + dashWidth, metric.length);
          canvas.drawPath(metric.extractPath(start, end), paint);
          distance = end + dashSpace;
        }
      }
    }

    final topRight = Rect.fromCircle(
      center: Offset(right - radius, top + radius),
      radius: radius,
    );
    final bottomRight = Rect.fromCircle(
      center: Offset(right - radius, bottom - radius),
      radius: radius,
    );
    final bottomLeft = Rect.fromCircle(
      center: Offset(left + radius, bottom - radius),
      radius: radius,
    );
    final topLeft = Rect.fromCircle(
      center: Offset(left + radius, top + radius),
      radius: radius,
    );

    canvas.drawArc(topRight, -math.pi / 2, math.pi / 2, false, paint);
    canvas.drawArc(bottomRight, 0, math.pi / 2, false, paint);
    canvas.drawArc(bottomLeft, math.pi / 2, math.pi / 2, false, paint);
    canvas.drawArc(topLeft, math.pi, math.pi / 2, false, paint);
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
