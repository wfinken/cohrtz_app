# Cohrtz UI Style Guidelines

This document defines baseline UI conventions for the Flutter app.

## Source of truth

- Use `Theme.of(context)` for runtime styling.
- Use `AppTheme` and `AppColors` as design tokens, not ad-hoc color values.
- Avoid hardcoded hex colors in feature widgets unless the value is semantic content data (for example, user avatar colors).

## Colors

- Prefer `theme.colorScheme` for primary/accent and on-surface text.
- Prefer `theme.cardColor` for panel surfaces.
- Prefer `theme.dividerColor` for borders and separators.
- Prefer `theme.hintColor` for tertiary text and low-emphasis icons.

## Typography

- Base typography comes from `AppTheme` (`GoogleFonts.interTextTheme`).
- Use `theme.textTheme` variants first, then override weight/size only when necessary.
- Use monospace only for code or markdown/code-editor content.

## Shape and spacing

- Card-like surfaces should respect app radii (`AppTheme.cardRadius` or feature-appropriate reduced radii).
- Keep internal spacing on an 8px rhythm (4/8/12/16/24).
- Use consistent separator treatment between stacked sections.

## Components and states

- Controls should use Material components (`IconButton`, `TextField`, `PopupMenuButton`, etc.) with themed colors.
- Selection/active states should use `theme.colorScheme.primary`.
- Preserve readable contrast in both dark and light themes.

## Notes feature conventions

- Full-page editor and dashboard list should both consume theme tokens.
- Editor chrome (tabs/toolbar/fields/sections) should not assume dark mode.
- Markdown preview styles should derive from theme colors and text styles.
