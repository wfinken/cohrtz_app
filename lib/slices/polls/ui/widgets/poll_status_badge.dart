import 'package:flutter/material.dart';

class PollStatusBadge extends StatelessWidget {
  final bool isPassed;

  const PollStatusBadge({super.key, required this.isPassed});

  @override
  Widget build(BuildContext context) {
    final color = isPassed ? const Color(0xFF10B981) : const Color(0xFFEF4444);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isPassed ? Icons.check : Icons.close, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            isPassed ? 'PASSED' : 'FAILED',
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}
