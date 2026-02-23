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
  bool isDisposedViewAssertion(Object error) {
    if (!kIsWeb) return false;
    final message = error.toString();
    return message.contains('Trying to render a disposed EngineFlutterView');
  }

  final previousFlutterOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    if (isDisposedViewAssertion(details.exception)) {
      debugPrint(
        '[Main] Suppressed benign web dispose assertion: ${details.exception}',
      );
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
      debugPrint('[Main] Suppressed benign web dispose assertion: $error');
      return true;
    }
    if (previousPlatformOnError != null) {
      return previousPlatformOnError(error, stack);
    }
    return false;
  };
}
