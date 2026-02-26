# Cohrtz Documentation

This documentation set is the canonical technical reference for Cohrtz contributors.
It is both:
- Descriptive: documents current behavior in the repository.
- Normative: defines required compatibility, security, and migration rules for future changes.

## Scope

This set covers:
- System architecture and trust boundaries
- End-to-end data flow (receive -> verify/decrypt -> store -> UI)
- CRDT storage schema, table contracts, and migration behavior
- Sync protocol internals and packet semantics
- Security model, threat model, and key lifecycle
- Version compatibility (N/N-1 policy)
- FOSS modability roadmap for widgets
- Operations runbooks and recovery procedures
- Testing and validation requirements

## Compatibility Contract

Cohrtz documentation targets **N/N-1 peer interoperability**.
- N = current released app version
- N-1 = immediately previous released app version

Peers are expected to interoperate within this window.
Outside this window, behavior is best-effort and may be degraded.

## Reading Order

1. [Architecture Overview](./architecture-overview.md)
2. [Data Flow](./data-flow.md)
3. [CRDT Schema Reference](./crdt-schema-reference.md)
4. [Sync Protocol](./sync-protocol.md)
5. [Security Model](./security-model.md)
6. [Versioning and Compatibility](./versioning-compatibility.md)
7. [Migrations Playbook](./migrations-playbook.md)
8. [Widget Modding](./modding-widgets.md)
9. [Operations Runbooks](./operations-runbooks.md)
10. [Testing and Validation](./testing-and-validation.md)
11. [Glossary](./appendix/glossary.md)
12. [Code Index](./appendix/code-index.md)

## Normative Language

The following keywords are used with RFC-style meaning:
- MUST
- MUST NOT
- SHOULD
- SHOULD NOT
- MAY

## Current Reality Snapshot

- Local persistence is CRDT-backed via `sql_crdt` with Drift adapters.
- Native clients persist CRDT data in encrypted SQLite files.
- Web currently uses an in-memory CRDT implementation in `crdt_service_web.dart`.
- Wire messages use protobuf `P2PPacket` and are signed per-packet.
- Group sync uses election-based responder selection and vector clock diffs.
- Group settings, roles, and members include explicit migration and compatibility handling in runtime paths.

## Future Documentation Candidates

Potential additional docs beyond this baseline:
- Performance and scaling playbook (latency, payload size, room-size thresholds)
- Product-level privacy/data-retention policy docs
- Contributor onboarding tutorial with end-to-end local dev walkthrough
