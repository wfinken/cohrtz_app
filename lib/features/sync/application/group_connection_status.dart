import 'package:flutter_riverpod/flutter_riverpod.dart';

enum StepStatus { pending, current, completed, error }

enum ConnectionProcessType { autoJoin, create, join }

class ConnectionStep {
  final String label;
  final StepStatus status;
  final String? errorMessage;

  const ConnectionStep({
    required this.label,
    this.status = StepStatus.pending,
    this.errorMessage,
  });

  ConnectionStep copyWith({
    String? label,
    StepStatus? status,
    String? errorMessage,
  }) {
    return ConnectionStep(
      label: label ?? this.label,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class ConnectionStatusState {
  final List<ConnectionStep> steps;
  final ConnectionProcessType type;
  final bool isVisible;
  final bool isSuccess;

  const ConnectionStatusState({
    required this.steps,
    required this.type,
    this.isVisible = false,
    this.isSuccess = false,
  });

  factory ConnectionStatusState.initial() {
    return const ConnectionStatusState(
      steps: [],
      type: ConnectionProcessType.autoJoin,
      isVisible: false,
    );
  }

  ConnectionStatusState copyWith({
    List<ConnectionStep>? steps,
    ConnectionProcessType? type,
    bool? isVisible,
    bool? isSuccess,
  }) {
    return ConnectionStatusState(
      steps: steps ?? this.steps,
      type: type ?? this.type,
      isVisible: isVisible ?? this.isVisible,
      isSuccess: isSuccess ?? this.isSuccess,
    );
  }
}

class GroupConnectionStatusNotifier extends Notifier<ConnectionStatusState> {
  @override
  ConnectionStatusState build() => ConnectionStatusState.initial();

  void startProcess(ConnectionProcessType type) {
    List<ConnectionStep> steps;
    switch (type) {
      case ConnectionProcessType.autoJoin:
        steps = [
          const ConnectionStep(label: 'Checking saved groups'),
          const ConnectionStep(label: 'Validating credentials'),
          const ConnectionStep(label: 'Connecting to mesh'),
        ];
        break;
      case ConnectionProcessType.create:
        steps = [
          const ConnectionStep(label: 'Checking invite room'),
          const ConnectionStep(label: 'Generating data room'),
          const ConnectionStep(label: 'Setting up permissions'),
          const ConnectionStep(label: 'Finalizing group'),
        ];
        break;
      case ConnectionProcessType.join:
        steps = [
          const ConnectionStep(label: 'Joining invite lobby'),
          const ConnectionStep(label: 'Handshaking with host'),
          const ConnectionStep(label: 'Transitioning to secure mesh'),
          const ConnectionStep(label: 'Verifying connection'),
        ];
        break;
    }

    state = ConnectionStatusState(steps: steps, type: type, isVisible: true);

    // Set first step to current
    updateStep(0, StepStatus.current);
  }

  void updateStep(int index, StepStatus status, {String? errorMessage}) {
    if (index < 0 || index >= state.steps.length) return;

    final newSteps = List<ConnectionStep>.from(state.steps);

    // Mark previous steps as completed if we are moving forward
    if (status == StepStatus.current) {
      for (int i = 0; i < index; i++) {
        if (newSteps[i].status != StepStatus.completed) {
          newSteps[i] = newSteps[i].copyWith(status: StepStatus.completed);
        }
      }
    }

    newSteps[index] = newSteps[index].copyWith(
      status: status,
      errorMessage: errorMessage,
    );

    state = state.copyWith(steps: newSteps);
  }

  void completeProcess() {
    // Mark all as completed
    final newSteps = state.steps
        .map((s) => s.copyWith(status: StepStatus.completed))
        .toList();
    state = state.copyWith(steps: newSteps, isSuccess: true);

    // Auto-hide after delay? Leave that to UI or explicit action?
    // For now, keep it visible until manual close or navigation.
  }

  void failProcess(String error) {
    // Find current step and mark error
    final index = state.steps.indexWhere(
      (s) => s.status == StepStatus.current || s.status == StepStatus.pending,
    );
    if (index != -1) {
      updateStep(index, StepStatus.error, errorMessage: error);
    }
  }

  void hide() {
    state = state.copyWith(isVisible: false);
  }
}

final groupConnectionStatusProvider =
    NotifierProvider<GroupConnectionStatusNotifier, ConnectionStatusState>(
      GroupConnectionStatusNotifier.new,
    );
