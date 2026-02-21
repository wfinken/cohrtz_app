import 'package:flutter_riverpod/flutter_riverpod.dart';

typedef ActivityBootstrapCallback = void Function(Ref ref);

class ActivityNotificationOrchestrator {
  const ActivityNotificationOrchestrator(this._bootstrap);

  final ActivityBootstrapCallback _bootstrap;

  void bootstrap(Ref ref) => _bootstrap(ref);
}
