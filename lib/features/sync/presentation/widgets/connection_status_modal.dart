import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cohortz/core/theme/dialog_button_styles.dart';
import '../../application/group_connection_status.dart';

class ConnectionStatusModal extends ConsumerStatefulWidget {
  const ConnectionStatusModal({super.key});

  @override
  ConsumerState<ConnectionStatusModal> createState() =>
      _ConnectionStatusModalState();
}

class _ConnectionStatusModalState extends ConsumerState<ConnectionStatusModal> {
  late final ProviderSubscription<ConnectionStatusState> _statusSubscription;

  @override
  void initState() {
    super.initState();
    _statusSubscription = ref.listenManual(groupConnectionStatusProvider, (
      previous,
      next,
    ) {
      if (next.isSuccess && (previous == null || !previous.isSuccess)) {
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted && ref.read(groupConnectionStatusProvider).isSuccess) {
            ref.read(groupConnectionStatusProvider.notifier).hide();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _statusSubscription.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final statusState = ref.watch(groupConnectionStatusProvider);

    if (!statusState.isVisible) {
      return const SizedBox.shrink();
    }

    return Stack(
      children: [
        // Modal Barrier
        ModalBarrier(
          dismissible: false,
          color: Colors.black.withValues(alpha: 0.5),
        ),
        // Dialog Content
        Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _getTitle(statusState.type),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  _buildStepper(context, statusState),
                  if (statusState.steps.any(
                    (s) => s.status == StepStatus.error,
                  )) ...[
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        ref.read(groupConnectionStatusProvider.notifier).hide();
                      },
                      style: dialogDestructiveButtonStyle(context),
                      child: const Text('Close'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _getTitle(ConnectionProcessType type) {
    switch (type) {
      case ConnectionProcessType.autoJoin:
        return 'Connecting to Group';
      case ConnectionProcessType.create:
        return 'Creating Group';
      case ConnectionProcessType.join:
        return 'Joining Group';
    }
  }

  Widget _buildStepper(BuildContext context, ConnectionStatusState state) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(state.steps.length * 2 - 1, (index) {
            if (index.isOdd) {
              // Line
              final stepIndex = index ~/ 2;
              final nextStep = state.steps[stepIndex + 1];
              final isPathActive =
                  nextStep.status == StepStatus.current ||
                  nextStep.status == StepStatus.completed ||
                  nextStep.status == StepStatus.error;

              return Expanded(
                child: Container(
                  height: 4,
                  color: isPathActive ? Colors.green : Colors.grey[300],
                ),
              );
            } else {
              // Circle
              final stepIndex = index ~/ 2;
              final step = state.steps[stepIndex];
              return _buildStepCircle(context, step, stepIndex + 1);
            }
          }),
        ),
        const SizedBox(height: 16),
        // Labels
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: state.steps.map((step) {
            return Expanded(
              child: Text(
                step.label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: step.status == StepStatus.current
                      ? FontWeight.bold
                      : FontWeight.normal,
                  color: _getColor(step.status),
                ),
              ),
            );
          }).toList(),
        ),
        // Error Message Display
        if (state.steps.any((s) => s.errorMessage != null))
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Text(
              state.steps
                  .firstWhere((s) => s.errorMessage != null)
                  .errorMessage!,
              style: const TextStyle(color: Colors.red, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }

  Widget _buildStepCircle(
    BuildContext context,
    ConnectionStep step,
    int index,
  ) {
    Color color;
    Widget child;

    switch (step.status) {
      case StepStatus.completed:
        color = Colors.green;
        child = const Icon(Icons.check, color: Colors.white, size: 16);
        break;
      case StepStatus.current:
        color = Colors.blue;
        child = const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
        );
        break;
      case StepStatus.error:
        color = Colors.red;
        child = const Icon(Icons.close, color: Colors.white, size: 16);
        break;
      case StepStatus.pending:
        color = Colors.grey[300]!;
        child = Text(
          '$index',
          style: const TextStyle(
            color: Colors.grey,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        );
        break;
    }

    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: child,
    );
  }

  Color _getColor(StepStatus status) {
    switch (status) {
      case StepStatus.completed:
        return Colors.green;
      case StepStatus.current:
        return Colors.blue;
      case StepStatus.error:
        return Colors.red;
      case StepStatus.pending:
        return Colors.grey;
    }
  }
}
