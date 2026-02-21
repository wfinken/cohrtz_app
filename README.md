# Cohrtz App

A local-first, peer-to-peer collaboration dashboard built with Flutter.

## Architecture

This project follows a Feature-First Clean Architecture approach.

### Directory Structure

```
lib/
├── core/               # Shared utilities, constants, and global providers
├── features/           # Feature-specific modules
│   ├── dashboard/      # Main dashboard UI and logic (draggables, grid)
│   ├── notes/          # Notes feature (Clean Architecture)
│   ├── vault/          # Secure storage feature
│   └── sync/           # Synchronization logic (P2P, Mesh)
└── main.dart           # App entry point
```

### Key Libraries

- **Riverpod**: State management
- **Flutter Dashboard Grid**: Bento-style grid layout
- **Drift + SQL CRDT**: Local-first persistence and synchronized conflict resolution
- **P2P Implementation**: Custom sync service (in progress)

## UI Conventions

- Follow `/Users/williamfinken/Documents/Github/cohrtz/app/STYLE_GUIDELINES.md` for color, typography, spacing, and themed component usage.
