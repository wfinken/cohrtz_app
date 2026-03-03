# Testing and Validation

## Summary

This document maps critical behaviors to current test coverage and defines mandatory validation scenarios for compatibility, security, and migrations.

## Existing Coverage Map

| Area | Representative Tests |
|---|---|
| Packet signing and tamper detection | `test/security/packet_security_test.dart` |
| End-to-end crypto exchange | `test/security/e2e_encryption_test.dart` |
| TreeKEM internals | `test/core/security/treekem/*` |
| Invite protocol behavior | `test/features/sync/application/invite_handler_test.dart` |
| Note repository semantics | `test/features/notes/note_repository_test.dart` |
| Model backward compatibility defaults | `test/slices/dashboard_shell/models/profile_serialization_test.dart` |
| Multi-client sync convergence (integration) | `integration_test/e2e/two_client_smoke_test.dart` |

## Integration Test Runtime Requirements

The integration smoke suite requires a reachable token endpoint and LiveKit backend.

- Backend connect smoke (`integration_test/e2e/backend_connect_smoke_test.dart`):
  - `COHRTZ_E2E_ENABLED=true`
  - `COHRTZ_E2E_ROOM=<room>`
  - `COHRTZ_E2E_IDENTITY=<identity>`
  - Example:
    - `flutter test integration_test/e2e/backend_connect_smoke_test.dart --dart-define=COHRTZ_E2E_ENABLED=true --dart-define=COHRTZ_E2E_ROOM=<room> --dart-define=COHRTZ_E2E_IDENTITY=<identity>`

- Multi-client convergence smoke (`integration_test/e2e/two_client_smoke_test.dart`):
  - Required defines:
    - `COHRTZ_E2E_ENABLED=true`
    - `COHRTZ_E2E_USER_COUNT=<count>` where `<count> >= 2`
  - Optional define:
    - `COHRTZ_E2E_ROOM_PREFIX=<prefix>` (default `cohrtz-e2e`)
  - Example:
    - `flutter test integration_test/e2e/two_client_smoke_test.dart --dart-define=COHRTZ_E2E_ENABLED=true --dart-define=COHRTZ_E2E_USER_COUNT=2`

## Known Gaps and Risks

Some tests are currently disabled or incomplete in migration context, including files that state disabled during sqlite3 migration.
Examples include:
- `test/features/sync/crdt_service_test.dart`
- `test/data_model_test.dart`
- `test/features/vault/packet_store_test.dart`

Risk impact:
- reduced confidence in migration and storage edge-case behavior
- increased regression risk for CRDT/runtime changes

## Required Compatibility Scenarios (N/N-1)

1. Wire compatibility
- N sender -> N-1 receiver for each packet family in active use
- N-1 sender -> N receiver merge and dispatch safety

2. Data compatibility
- N writes model with new optional fields; N-1 parses with defaults
- legacy rows are read-repaired to canonical forms

3. Key-state compatibility
- client rejoins with missing in-memory key but existing persistent key
- client receives GSK update after buffered encrypted packets

4. Migration compatibility
- startup migration idempotence (repeat launch)
- rollback viability after partial migration

## Security Regression Scenarios

- packet signature invalid after payload tamper
- packet rejected when public key mismatch
- packet rejected when unsigned
- decrypt failure paths do not cause unsafe state mutation
- RBAC rejects unauthorized role/member/logical-group changes

## Release Acceptance Gates

A release is accepted only if:
- all mandatory unit/widget tests pass
- integration suite passes for core sync flows
- compatibility/migration checklist in `migrations-playbook.md` passes
- no high-severity unresolved security regressions

## Traceability Matrix (Doc -> Code -> Test)

| Claim | Code Area | Validation |
|---|---|---|
| per-packet signature verification before merge | `PacketHandler._processVerifiedPacket` | packet security tests |
| invite single-use token cleanup across duplicate rows | `InviteHandler.handleInviteReq` | invite handler tests |
| legacy profile/group settings defaults preserved | mapper models | profile serialization compatibility test |
| two-client convergence across major feature tables | sync runtime + repositories | two-client E2E smoke suite |

## Related Docs

- [Versioning and Compatibility](./versioning-compatibility.md)
- [Migrations Playbook](./migrations-playbook.md)
- [Security Model](./security-model.md)
