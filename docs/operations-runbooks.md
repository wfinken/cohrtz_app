# Operations Runbooks

## Summary

This guide defines operational procedures for reliability, recovery, and release safety.

## Observability Signals

Primary sources:
- runtime logs (`Log.d/i/w/e` in sync/security/runtime components)
- sync diagnostics stream (`SyncDiagnostics`)
- room connection states (`ConnectionManager`)
- consistency hash/count diagnostics
- packet store snapshots (native/web variants)

## Incident Triage Template

Collect first:
- room name
- local participant id
- packet type and request id (if available)
- connection state transitions
- whether issue reproduces after handshake/sync retry

## Runbook: Token Invalid or Expired

Symptoms:
- connect failures with token warnings
- repeated reconnect loop

Actions:
1. verify token endpoint availability and response format
2. force token refresh path by reconnect
3. verify identity bound in token payload
4. confirm saved tokens for room are refreshed in secure storage

## Runbook: Missing Group Key (GSK)

Symptoms:
- encrypted packet decryption failure
- buffered packet queue growth

Actions:
1. ensure handshake has remote encryption keys
2. trigger GSK request/retry flow
3. verify `TreeKemHandler` service presence and epoch updates
4. confirm buffered packets replay after key update
5. if still failing, disconnect/reconnect room and inspect consistency diagnostics

## Runbook: Vault Key Unavailable

Symptoms:
- vault decrypt failures
- timeout waiting for vault key

Actions:
1. check whether key was previously initialized (`vault_key_initialized_*` semantics)
2. request key from peers
3. if authority and uninitialized, controlled generation path may proceed
4. if previously initialized but missing, do not silently regenerate; recover from peer share

## Runbook: Database Corruption on Native

Symptoms:
- sqlite open errors with "file is not a database"

Actions:
1. capture logs and room/db filename
2. confirm corruption handling path recreated DB file
3. trigger sync recovery from peers
4. validate post-recovery convergence (count/hash)

## Runbook: Sync Divergence

Symptoms:
- peers show different entity counts/content after expected convergence window

Actions:
1. run consistency check and compare diagnostics
2. inspect packet flow for dropped signature/decrypt failures
3. trigger forced sync request
4. inspect RBAC merge rejections for roles/members/logical_groups
5. validate both peers are within N/N-1 compatibility window

## Backup and Recovery Guidance

- Native rooms persist per-room DB files (`cohrtz_<sanitized>.db`).
- Secure key/value store persists in secure blob DB (native) or browser prefs (web).
- For manual backup, include both CRDT DB and secure key store artifacts; restoring only one may break decryption paths.

## Release and Rollback Checklist

Pre-release:
- [ ] N/N-1 compatibility suites pass
- [ ] migration checklist pass
- [ ] no new critical security findings
- [ ] operations docs updated for new failure modes

Rollback trigger examples:
- widespread decrypt failures after release
- unrecoverable migration corruption
- protocol behavior causing cross-version partitioning

Rollback actions:
1. freeze rollout
2. publish rollback build/hotfix
3. apply recovery playbook per impacted rooms
4. backfill regression tests before re-release

## Related Docs

- [Security Model](./security-model.md)
- [Sync Protocol](./sync-protocol.md)
- [Versioning and Compatibility](./versioning-compatibility.md)
