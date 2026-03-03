# CRDT Migration Plan (`sql_crdt` -> `drift_crdt`)

## Status

This is a planning document for a follow-up migration phase.
The current runtime in this repository remains on `sql_crdt`.

## Why Separate the Migration

Current runtime paths are tightly coupled to:

- `SqlCrdt` APIs from `sql_crdt`
- custom `sqlite3` executor wiring (`CrdtQueryExecutor`)
- native encrypted open path in `EncryptedSqliteCrdt` using `PRAGMA key`

Because those areas are security-sensitive and shared by sync/runtime flows, migration is intentionally split from public-readiness cleanup.

## Current Touchpoints

Primary files using `sql_crdt` directly:

- `lib/shared/database/crdt_executor.dart`
- `lib/shared/database/crdt/encrypted_sqlite_crdt.dart`
- `lib/slices/sync/runtime/crdt_service_native.dart`
- `lib/slices/sync/runtime/crdt_service_web.dart`
- `lib/slices/sync/orchestration/sync_protocol.dart`
- `lib/slices/sync/runtime/hlc_compat.dart`

## Migration Goals

- Replace direct `sql_crdt` dependencies with `drift_crdt` equivalents where viable.
- Preserve on-disk data compatibility and merge semantics.
- Preserve encryption-at-rest behavior on native platforms.
- Keep existing sync protocol behavior and packet-level guarantees.

## Known Risks

- API mismatch between `sql_crdt` and `drift_crdt` types and executors.
- Encryption path regressions if native open/key behavior changes.
- Drift watcher/update behavior changes during merge operations.
- Web/native behavior divergence during transition.

## Required Validation Before Merge

- `flutter analyze` clean.
- `flutter test` full suite clean.
- Integration smoke suite passes in backend-enabled environment:
  - `integration_test/e2e/two_client_smoke_test.dart`
- Focused regression suite for CRDT runtime:
  - `test/features/sync/runtime/crdt_service_web_test.dart`
  - `test/features/sync/runtime/encrypted_sqlite_crdt_test.dart`
  - `test/features/sync/application/invite_join_process_test.dart`
  - `test/features/sync/application/invite_handler_test.dart`

## Rollout Approach

1. Introduce adapter layer for CRDT API usage behind internal interfaces.
2. Switch one runtime target at a time (web first, then native).
3. Run full validation gates after each switch.
4. Remove deprecated CRDT dependency only after parity is verified.
