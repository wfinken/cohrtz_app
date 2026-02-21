import 'package:flutter/material.dart';

class PollProgressBar extends StatelessWidget {
  final double approvedPct;
  final double refusedPct;
  final int approvedCount;
  final int refusedCount;
  final int goal;

  const PollProgressBar({
    super.key,
    required this.approvedPct,
    required this.refusedPct,
    required this.approvedCount,
    required this.refusedCount,
    required this.goal,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final remainingPct = (1.0 - approvedPct - refusedPct).clamp(0.0, 1.0);

    return Container(
      height: 8,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          if (approvedPct > 0)
            Expanded(
              flex: (approvedPct * 1000).toInt(),
              child: Container(
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  borderRadius: BorderRadius.horizontal(
                    left: const Radius.circular(999),
                    right: Radius.circular(
                      (refusedPct > 0 || remainingPct > 0) ? 0 : 999,
                    ),
                  ),
                ),
              ),
            ),
          if (refusedPct > 0)
            Expanded(
              flex: (refusedPct * 1000).toInt(),
              child: Container(
                decoration: BoxDecoration(
                  color: colorScheme.error,
                  borderRadius: BorderRadius.horizontal(
                    left: Radius.circular(approvedPct > 0 ? 0 : 999),
                    right: Radius.circular(remainingPct > 0 ? 0 : 999),
                  ),
                ),
              ),
            ),
          if (remainingPct > 0)
            Expanded(
              flex: (remainingPct * 1000).toInt(),
              child: const SizedBox.shrink(),
            ),
        ],
      ),
    );
  }
}
