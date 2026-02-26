# Code Index

## App Bootstrap and DI

- `lib/main.dart`
- `lib/app/main_app.dart`
- `lib/app/di/app_providers.dart`
- `lib/app/di/providers/*`

## Sync Runtime and Orchestration

- `lib/slices/sync/runtime/connection_manager.dart`
- `lib/slices/sync/runtime/crdt_service_native.dart`
- `lib/slices/sync/runtime/crdt_service_web.dart`
- `lib/slices/sync/runtime/data_broadcaster.dart`
- `lib/slices/sync/runtime/key_manager.dart`
- `lib/slices/sync/runtime/group_manager.dart`
- `lib/slices/sync/runtime/treekem_handler.dart`
- `lib/slices/sync/orchestration/packet_handler.dart`
- `lib/slices/sync/orchestration/sync_protocol.dart`
- `lib/slices/sync/orchestration/handshake_handler.dart`
- `lib/slices/sync/orchestration/invite_handler.dart`

## Security

- `lib/shared/security/security_service.dart`
- `lib/shared/security/encryption_service.dart`
- `lib/shared/security/secure_storage_service.dart`
- `lib/shared/security/master_key_provider.dart`
- `lib/shared/security/encrypted_envelope_codec.dart`
- `lib/shared/security/native_sql_blob_backend.dart`
- `lib/shared/security/web_secure_prefs_backend.dart`
- `lib/shared/security/treekem/*`

## Database and CRDT Integration

- `lib/shared/database/database.dart`
- `lib/shared/database/crdt_executor.dart`
- `lib/shared/database/crdt/encrypted_sqlite_crdt.dart`

## Feature Repositories and Models

- `lib/slices/dashboard_shell/state/dashboard_repository.dart`
- `lib/slices/dashboard_shell/state/repositories/*`
- `lib/slices/notes/state/note_repository.dart`
- `lib/slices/permissions_feature/state/*`
- `lib/slices/dashboard_shell/models/*`
- `lib/slices/permissions_feature/models/*`

## Widget Rendering and Modding Surface

- `lib/slices/dashboard_shell/models/dashboard_widget.dart`
- `lib/slices/dashboard_shell/ui/widgets/dashboard_grid_view.dart`
- `lib/slices/dashboard_shell/ui/widgets/widget_container.dart`
- `lib/slices/dashboard_shell/state/local_dashboard_storage.dart`

## Wire Schema

- `protos/p2p_packet.proto`
- `lib/src/generated/p2p_packet.pb.dart`

## Tests

- `test/security/*`
- `test/core/security/treekem/*`
- `test/features/sync/application/invite_handler_test.dart`
- `test/slices/dashboard_shell/models/profile_serialization_test.dart`
- `integration_test/e2e/two_client_smoke_test.dart`
