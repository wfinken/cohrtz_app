# Glossary

- ACL: Access control list. Defines who can view/edit actions.
- CRDT: Conflict-free replicated data type. Enables eventual convergence without central lockstep.
- Drift: Dart persistence layer and query abstraction over SQLite executors.
- GSK: Group secret key used for shared encrypted broadcast payloads.
- HLC: Hybrid logical clock value used for CRDT ordering metadata.
- Invite Room: Temporary low-privilege room used for invite handshake.
- N/N-1: Compatibility policy where current and previous app versions must interoperate.
- Packet Store: Optional store of received packet chunks for diagnostics/audit visibility.
- Pairwise Key: Derived symmetric secret between two peers from X25519 exchange.
- TreeKEM: Tree-based group key management mechanism used for group secret evolution.
- Vector Clock: Map of node id -> max observed HLC used to compute deltas.
- Tombstone: CRDT delete representation allowing delete convergence across peers.
