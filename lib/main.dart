import 'package:flutter/material.dart';
import 'app/bootstrap/app_bootstrap.dart';
import 'app/main_app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final appScope = await createAppProviderScope(child: const MainApp());
  runApp(appScope);
}
