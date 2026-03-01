import 'package:flutter_test/flutter_test.dart';

const int _e2eUserCountForTimeout = int.fromEnvironment(
  'COHRTZ_E2E_USER_COUNT',
  defaultValue: 2,
);

Future<void> expectEventually({
  required Future<bool> Function() condition,
  required String description,
  Duration? timeout,
  Duration? interval,
}) async {
  final effectiveTimeout = timeout ?? _adaptiveTimeout();
  final effectiveInterval = interval ?? _adaptiveInterval();
  final deadline = DateTime.now().add(effectiveTimeout);
  Object? lastError;

  while (DateTime.now().isBefore(deadline)) {
    try {
      if (await condition()) {
        return;
      }
    } catch (error) {
      lastError = error;
    }
    await Future<void>.delayed(effectiveInterval);
  }

  final suffix = lastError == null ? '' : ' Last error: $lastError';
  fail('$description (timeout: ${effectiveTimeout.inSeconds}s).$suffix');
}

Duration _adaptiveTimeout() {
  if (_e2eUserCountForTimeout <= 2) {
    return const Duration(seconds: 20);
  }
  final seconds = (_e2eUserCountForTimeout * 8).clamp(30, 180);
  return Duration(seconds: seconds);
}

Duration _adaptiveInterval() {
  if (_e2eUserCountForTimeout <= 4) {
    return const Duration(milliseconds: 200);
  }
  return const Duration(milliseconds: 350);
}
