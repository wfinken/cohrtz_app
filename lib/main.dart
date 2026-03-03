import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'app/bootstrap/app_bootstrap.dart';
import 'app/main_app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _configureGlobalErrorHandling();
  final appScope = await createAppProviderScope(child: const MainApp());
  runApp(appScope);
}

void _configureGlobalErrorHandling() {
  final webDisposeAssertionTracker = _SuppressedWebDisposeAssertionTracker();

  bool isDisposedViewAssertion(Object error) {
    if (!kIsWeb) return false;
    final message = error.toString();
    return message.contains('Trying to render a disposed EngineFlutterView');
  }

  final previousFlutterOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    if (isDisposedViewAssertion(details.exception)) {
      final logMessage = webDisposeAssertionTracker.record(details.exception);
      if (logMessage != null) {
        debugPrint(logMessage);
      }
      return;
    }
    if (previousFlutterOnError != null) {
      previousFlutterOnError(details);
    } else {
      FlutterError.presentError(details);
    }
  };

  final previousPlatformOnError = PlatformDispatcher.instance.onError;
  PlatformDispatcher.instance.onError = (error, stack) {
    if (isDisposedViewAssertion(error)) {
      final logMessage = webDisposeAssertionTracker.record(error);
      if (logMessage != null) {
        debugPrint(logMessage);
      }
      return true;
    }
    if (previousPlatformOnError != null) {
      return previousPlatformOnError(error, stack);
    }
    return false;
  };
}

class _SuppressedWebDisposeAssertionTracker {
  int _count = 0;
  DateTime? _lastLogAt;

  String? record(Object error) {
    _count += 1;

    final now = DateTime.now();
    final shouldLog =
        _count == 1 ||
        _count % 25 == 0 ||
        _lastLogAt == null ||
        now.difference(_lastLogAt!) > const Duration(seconds: 30);

    if (!shouldLog) {
      return null;
    }

    _lastLogAt = now;
    return '[Main] Suppressed benign web dispose assertion '
        '(count=$_count): ${error.toString().split('\n').first}';
  }
}
