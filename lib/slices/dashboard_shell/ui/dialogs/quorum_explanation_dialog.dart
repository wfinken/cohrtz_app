import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/di/app_providers.dart';

class QuorumExplanationDialog extends ConsumerWidget {
  const QuorumExplanationDialog({super.key, int? onlineCount});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isConnected = ref.watch(
      syncServiceProvider.select((s) => s.isActiveRoomConnected),
    );
    final remoteParticipants = ref.watch(
      syncServiceProvider.select((s) => s.remoteParticipants),
    );
    final onlineCount = isConnected ? 1 + remoteParticipants.length : 0;

    Color getQuorumColor() {
      if (onlineCount <= 1) return Colors.red;
      if (onlineCount == 2) return Colors.amber;
      return Colors.green;
    }

    String getQuorumLevel() {
      if (onlineCount <= 0) return 'Offline';
      if (onlineCount == 1) return 'Solo Node';
      if (onlineCount == 2) return 'Partial Quorum';
      return 'Full Quorum';
    }

    return Dialog(
      backgroundColor: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        padding: const EdgeInsets.all(32),
        constraints: const BoxConstraints(maxWidth: 450),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.handshake,
                            color: Theme.of(context).colorScheme.primary,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Quorum Status',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
                                ),
                              ),
                              Text(
                                getQuorumLevel(),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: getQuorumColor(),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'What is a Quorum?',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'A quorum is the minimum number of nodes required to ensure data consistency and availability in a peer-to-peer network.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).hintColor,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).dividerColor.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Theme.of(
                            context,
                          ).dividerColor.withValues(alpha: 0.1),
                        ),
                      ),
                      child: Column(
                        children: [
                          _buildLevelRow(
                            context,
                            1,
                            'Local Only',
                            'Data exists on your device. High risk of loss if device fails.',
                            onlineCount == 1,
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Divider(height: 1),
                          ),
                          _buildLevelRow(
                            context,
                            2,
                            'Basic Redundancy',
                            'Data is mirrored on one other device. Improved availability.',
                            onlineCount == 2,
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Divider(height: 1),
                          ),
                          _buildLevelRow(
                            context,
                            3,
                            'Robust Integrity',
                            'Strong consensus reached. High reliability and distribution.',
                            onlineCount >= 3,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Understood'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLevelRow(
    BuildContext context,
    int count,
    String title,
    String desc,
    bool isActive,
  ) {
    final color = count == 1
        ? Colors.red
        : (count == 2 ? Colors.amber : Colors.green);

    return Opacity(
      opacity: isActive ? 1.0 : 0.4,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                count == 3 ? '3+' : count.toString(),
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  desc,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).hintColor,
                  ),
                ),
              ],
            ),
          ),
          if (isActive) Icon(Icons.check_circle, color: color, size: 20),
        ],
      ),
    );
  }
}
