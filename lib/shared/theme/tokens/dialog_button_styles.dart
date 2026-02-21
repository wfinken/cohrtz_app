import 'package:flutter/material.dart';

ButtonStyle dialogElevatedButtonStyle(BuildContext context) =>
    Theme.of(context).elevatedButtonTheme.style ?? const ButtonStyle();

ButtonStyle dialogDestructiveButtonStyle(BuildContext context) {
  final theme = Theme.of(context);
  return dialogElevatedButtonStyle(context).copyWith(
    backgroundColor: WidgetStateProperty.all(theme.colorScheme.error),
    foregroundColor: WidgetStateProperty.all(theme.colorScheme.onError),
  );
}
