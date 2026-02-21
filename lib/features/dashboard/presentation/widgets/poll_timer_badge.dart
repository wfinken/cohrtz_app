import 'package:flutter/material.dart';

class PollTimerBadge extends StatelessWidget {
  final bool isUrgent;
  final DateTime endTime;

  const PollTimerBadge({
    super.key,
    required this.isUrgent,
    required this.endTime,
  });

  @override
  Widget build(BuildContext context) {
    final difference = endTime.difference(DateTime.now());
    final hours = difference.inHours;
    final minutes = difference.inMinutes % 60;

    final color = isUrgent ? const Color(0xFFf43f5e) : Colors.grey;
    final bg = isUrgent
        ? const Color(0xFFf43f5e).withValues(alpha: 0.1)
        : Colors.grey.withValues(alpha: 0.1);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer_outlined, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            '${hours}h ${minutes}m',
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
