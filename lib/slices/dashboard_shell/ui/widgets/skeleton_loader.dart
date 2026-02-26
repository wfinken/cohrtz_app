import 'package:flutter/material.dart';

import '../../../../shared/theme/tokens/app_shape_tokens.dart';
import '../../../../shared/theme/tokens/app_semantic_colors.dart';

AppSemanticColors _semanticColors(BuildContext context) {
  final theme = Theme.of(context);
  return theme.extension<AppSemanticColors>() ??
      (theme.brightness == Brightness.dark
          ? AppSemanticColors.dark()
          : AppSemanticColors.light());
}

/// Base shimmer animation widget
class SkeletonLoader extends StatefulWidget {
  final Widget child;

  const SkeletonLoader({super.key, required this.child});

  @override
  State<SkeletonLoader> createState() => _SkeletonLoaderState();
}

class _SkeletonLoaderState extends State<SkeletonLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
    _animation = Tween<double>(
      begin: -1.0,
      end: 2.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final semantic = _semanticColors(context);
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                semantic.skeletonBase,
                semantic.skeletonHighlight,
                semantic.skeletonBase,
              ],
              stops: [
                _animation.value - 0.3,
                _animation.value,
                _animation.value + 0.3,
              ].map((s) => s.clamp(0.0, 1.0)).toList(),
            ).createShader(bounds);
          },
          blendMode: BlendMode.srcIn,
          child: widget.child,
        );
      },
    );
  }
}

/// Rectangular skeleton box
class SkeletonBox extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;

  const SkeletonBox({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8,
  });

  @override
  Widget build(BuildContext context) {
    final semantic = _semanticColors(context);
    final resolvedRadius = resolveAppRadius(context, borderRadius);
    return SkeletonLoader(
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: semantic.skeletonBase,
          borderRadius: BorderRadius.circular(resolvedRadius),
        ),
      ),
    );
  }
}

/// Circular skeleton for avatars
class SkeletonCircle extends StatelessWidget {
  final double size;

  const SkeletonCircle({super.key, required this.size});

  @override
  Widget build(BuildContext context) {
    final semantic = _semanticColors(context);
    return SkeletonLoader(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: semantic.skeletonBase,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

/// Skeleton for task items
class SkeletonTaskItem extends StatelessWidget {
  const SkeletonTaskItem({super.key});

  @override
  Widget build(BuildContext context) {
    final semantic = _semanticColors(context);
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.28),
        borderRadius: context.appBorderRadius(12),
        border: Border.all(color: semantic.skeletonBase),
      ),
      child: const Row(
        children: [
          SkeletonBox(width: 16, height: 16, borderRadius: 4),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(width: 150, height: 12, borderRadius: 4),
                SizedBox(height: 6),
                SkeletonBox(width: 80, height: 10, borderRadius: 4),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Skeleton for calendar events
class SkeletonEventItem extends StatelessWidget {
  const SkeletonEventItem({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      child: const Row(
        children: [
          SkeletonBox(width: 44, height: 48, borderRadius: 8),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(width: 120, height: 14, borderRadius: 4),
                SizedBox(height: 6),
                SkeletonBox(width: 160, height: 11, borderRadius: 4),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Skeleton for vault items
class SkeletonVaultItem extends StatelessWidget {
  const SkeletonVaultItem({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      child: const Row(
        children: [
          SkeletonBox(width: 20, height: 20, borderRadius: 4),
          SizedBox(width: 12),
          Expanded(child: SkeletonBox(width: 100, height: 14, borderRadius: 4)),
          SkeletonBox(width: 16, height: 16, borderRadius: 4),
        ],
      ),
    );
  }
}

/// Skeleton for chat messages
class SkeletonChatMessage extends StatelessWidget {
  final bool isMe;

  const SkeletonChatMessage({super.key, this.isMe = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMe) ...[
            const SkeletonCircle(size: 32),
            const SizedBox(width: 12),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isMe
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                SkeletonBox(width: 60, height: 12, borderRadius: 4),
                const SizedBox(height: 4),
                SkeletonBox(
                  width: isMe ? 150 : 200,
                  height: 48,
                  borderRadius: 16,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Tasks loading skeleton
class TasksLoadingSkeleton extends StatelessWidget {
  const TasksLoadingSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
      physics: NeverScrollableScrollPhysics(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [SkeletonTaskItem(), SkeletonTaskItem(), SkeletonTaskItem()],
      ),
    );
  }
}

/// Calendar loading skeleton
class CalendarLoadingSkeleton extends StatelessWidget {
  const CalendarLoadingSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
      physics: NeverScrollableScrollPhysics(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SkeletonEventItem(),
          SkeletonEventItem(),
          SkeletonEventItem(),
        ],
      ),
    );
  }
}

/// Vault loading skeleton
class VaultLoadingSkeleton extends StatelessWidget {
  const VaultLoadingSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
      physics: NeverScrollableScrollPhysics(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SkeletonVaultItem(),
          SkeletonVaultItem(),
          SkeletonVaultItem(),
        ],
      ),
    );
  }
}

/// Chat loading skeleton
class ChatLoadingSkeleton extends StatelessWidget {
  const ChatLoadingSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
      physics: NeverScrollableScrollPhysics(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SkeletonChatMessage(isMe: false),
          SkeletonChatMessage(isMe: true),
          SkeletonChatMessage(isMe: false),
        ],
      ),
    );
  }
}
