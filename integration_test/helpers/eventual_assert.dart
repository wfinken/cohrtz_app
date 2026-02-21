import 'package:flutter_test/flutter_test.dart';

Future<void> expectEventually({
  required Future<bool> Function() condition,
  required String description,
  Duration timeout = const Duration(seconds: 20),
  Duration interval = const Duration(milliseconds: 200),
}) async {
  final deadline = DateTime.now().add(timeout);
  Object? lastError;

  while (DateTime.now().isBefore(deadline)) {
    try {
      if (await condition()) {
        return;
      }
    } catch (error) {
      lastError = error;
    }
    await Future<void>.delayed(interval);
  }

  final suffix = lastError == null ? '' : ' Last error: $lastError';
  fail('$description (timeout: ${timeout.inSeconds}s).$suffix');
}
