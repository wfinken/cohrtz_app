# Cohrtz

> **The Operating System for Your Inner Circle**

Cohrtz is a privacy-first, local-centric "Super App" designed for micro-communities—families, gaming guilds, sports teams, and roommates. It provides a unified dashboard to manage your shared digital life without selling your data to the highest bidder.

## 🚀 Core Philosophy

- **Local-First & Serverless**: Data lives on your device, stored in a local **encrypted database (SQLCipher)** via `sqlite_crdt`. There is no central "Master" database holding your secrets. We trust your hardware, not our servers.
- **P2P Synchronization via LiveKit**: We utilize LiveKit strictly as a high-speed transport layer (SFU/Mesh relay). Data is synchronized directly between peers using WebRTC Data Channels, CRDTs, and Delta Encoding.
- **Hybrid Sovereignty**: While the Data Plane is peer-to-peer and self-sovereign, we maintain a lightweight "Mothership" (Control Plane) concept for future essential services like payment verification, though currently, the system operates without mandatory login.

## 🧩 Features

The UI is built around a modular "Bento Box" grid system that adapts its vocabulary and layout based on the group context.

- **📊 Polls**: Create and participate in real-time group polls with synchronized results.
- **🔐 Permissions**: Granular, role-based access control for widgets and group actions.
- **📍 Location (The Beacon)**: Real-time, opt-in location sharing.
- **📅 Calendar (The Prophecies)**: Shared events synchronized via Vector Clocks to handle offline edits.
- **🛡️ The Vault**: End-to-End Encrypted (AES-GCM) storage for credentials and sensitive docs, utilizing room-specific keys derived via **X25519**.
- **✅ Tasks**: CRDT-backed to-do lists that survive offline edits.
- **💬 Chat (The Hearth)**: Append-only logs synchronized via the mesh.
- **📝 Notes**: Collaborative documents.
- **📰 Activity Feed**: A chronological feed for life updates and achievements.
- **開 Storage Management**: Monitor per-group storage usage directly from group settings.

## 🏗️ Technical Architecture

### The Data Plane (Serverless P2P)
Cohrtz bypasses traditional REST APIs for data storage. Every client is a database node.

- **Topology**: Star Topology via LiveKit SFU, functionally acting as a P2P Mesh resource.
- **Transport**: WebRTC Data Channels (Reliable/Ordered).
- **Serialization**: Protocol Buffers (Protobuf) for all wire traffic.
- **Conflict Resolution**: Conflict-free Replicated Data Types (CRDTs) ensure eventual consistency using `sqlite_crdt`.

### The "Volunteer" Election & Secure Unicast Sync
To prevent bandwidth storms and enhance privacy, Cohrtz implements a **Secure Multicast-to-Unicast** sync protocol:

1. **Discovery**: A peer missing data broadcasts a `SYNC_REQ` to the mesh.
   - When the Group Secret Key (GSK) is available, `SYNC_REQ` and `SYNC_CLAIM` are GSK‑encrypted broadcasts.
   - If the GSK is not yet available (e.g., first join), the protocol falls back to pairwise unicast.
2. **Backoff**: Receiving peers calculate a random delay (Volunteer Election).
3. **Claim**: The first peer to wake up wins the election and broadcasts a `SYNC_CLAIM`.
4. **Direct Transmission**: The winner acts as the *Source*. They securely encrypt the data specifically for the *Requester*.
5. **Secure Delivery**: Using LiveKit's `publishData` with `destinationIdentities`, the encrypted payload is sent directly to the requester, bypassing other peers.
6. **Efficiency**: This eliminates the overhead of creating temporary rooms while maintaining strict pair-wise encryption.

---

## 🔒 Security Protocol: A Verbose Explanation

Security is the cornerstone of Cohrtz. We believe in "Trust No One" (Zero Trust) architecture.

### For the Non-Technical User (The "Layman's" View)
Think of Cohrtz like a private meeting room with specific security rules:

1.  **The Digital Wax Seal (Identity)**: Every time you send a message, add a task, or update the calendar, your app stamps it with a unique "Digital Wax Seal" (Signature). Only you have the stamp. If anyone tries to tamper with the message in transit, the seal breaks, and the group rejects it.
2.  **The Armored Truck (Transport)**: When we send data to your friends, we don't just mail it. We put it inside an "Armored Truck" (WebRTC Encryption). Even if someone intercepts the truck on the highway (the internet), they can't see what's inside.
3.  **Your Personal Safe (Storage)**: Your data isn't stored in our filing cabinet in the cloud. It is stored in *your* personal safe (your device). We don't have the key.
4.  **The Group Skeleton Key (Shared Chat)**: For group conversations and shared updates, we create a special "skeleton key" that every member of your room holds. Even the people running the "Armored Truck" company (LiveKit) can't see the contents—only your group has the key.

### For the Technical User (The Engineer's View)
Here is exactly how we implement the security stack:

#### 1. Identity & Authorship (Ed25519)
-   **Algorithm**: We use **Ed25519** (Edwards-curve Digital Signature Algorithm) for identity and Message Layer Security (MLS).
-   **Packet Signing**: Every single `P2PPacket` sent over the network is signed using the sender's Private Key. The signature covers a deterministic byte-array of critical fields: `type`, `requestId`, `senderId`, `payload`, and metadata (chunks, encryption status).
-   **Verification**: Receivers extract the `sender_public_key` from the packet (or use a previously cached key) and perform `Ed25519_Verify(DeterministicPayload, Signature, PublicKey)`. If verification fails, the packet is dropped immediately. This ensures total authenticity and integrity for both Unicast and Broadcast traffic.

#### 2. Transport Security (DTLS/SRTP)
-   **Layer**: We leverage the standard WebRTC security stack.
-   **Encryption**: All Data Channels are encrypted using **DTLS** (Datagram Transport Layer Security). Media is encrypted via **SRTP**.
-   **Properties**: This ensures Confidentiality, Integrity, and Authenticity of the *channel* between peers (or peer-to-SFU).

#### 3. Data-at-Rest
-   **Database**: Data is stored using **SQLCipher** for full-disk encryption on native platforms.
-   **Key Management**: The database encryption key is generated locally using high-entropy random bytes and stored securely in the platform's **Secure Storage**.
-   **Encryption**: Peer identity keys (Ed25519) and encryption keys (X25519) are stored securely.
-   **Isolation**: On Mobile (iOS/Android), app sandboxing isolates the data from other apps.

#### 4. End-to-End Encryption (E2EE) - Direct Unicast & Invite Flow
-   **Context**: For heavy data sync, sensitive transfers (Multi-Unicast fallback), and the initial invite handshake.
-   **Key Exchange**: We use **X25519** for Diffie-Hellman key exchange and session key derivation.
-   **Two-Stage Join Flow**:
    1.  **Invite Room**: New peers join a temporary, low-privilege "Invite Room" using an 8-character alphanumeric code (segmented input with auto-tabbing).
    2.  **Encrypted Handshake**: A fully E2EE unicast channel is established to securely exchange transit keys and the real Data Room UUID.
-   **Vault E2EE**: Items in the Vault are encrypted using **AES-GCM-256**. The encryption key is derived using **X25519** and **HKDF**, ensuring that only members with the room's shared secret can access the content.
-   **Session Keys**: A unique **AES-GCM-256** session key is derived for *each* pair of peers using HKDF.
    -   **Salt**: The active `roomName` or `inviteCode` is used as a salt, binding the session key to the specific group context.
    -   **Derivation**: `SessionKey = HKDF(MyPrivKey + TheirPubKey, Salt)`.
-   **Payload**: The application payload is encrypted and signed. The LiveKit relay server sees only the encrypted ciphertext and the routing destination.

#### 5. Scalable Group Encryption (TreeKEM / MLS)
-   **Context**: For mesh broadcasts (DATA_CHUNK, SYNC_REQ, etc.) where linear key distribution is inefficient ($O(N)$).
-   **Algorithm**: We enable **TreeKEM** (Tree-based Key Encapsulation Mechanism), a core component of the **MLS (Message Layer Security)** protocol (RFC 9420).
-   **Structure**: Peers are organized into a binary **Ratchet Tree**. Each node in the tree represents a public/private key pair (HPKE / X25519). The root of the tree represents the shared **Group Secret**.
-   **Efficiency**: Join, Leave, and Key Rotation operations have **$O(\log N)$** complexity, making the system scalable for larger groups compared to pairwise meshes.
-   **Properties**:
    -   **Forward Secrecy (FS)**: When a member updates their key or leaves, a new Group Secret is derived that they cannot access, protecting future messages.
    -   **Post-Compromise Security (PCS)**: If a member's key is compromised, a successful update heals the session, securing future communications.
-   **Mechanism**:
    -   **Welcome**: The Host expands the tree and sends an encrypted `WELCOME` packet containing the new member's private path secrets.
    -   **Update**: Members periodically broadcast an `UPDATE` packet (containing a new `UpdatePath`) to rotate the tree keys and the Group Secret.

> **Note on E2EE**: All traffic in Cohrtz is now fully End-to-End Encrypted (E2EE). Targeted Unicast transfers use pair-wise session keys, while general mesh broadcasts utilize a shared Group Secret Key (GSK) managed via the **TreeKEM** protocol. The LiveKit relay server sees only encrypted ciphertext.

---

## 🛠️ Tech Stack

- **Frontend**: Flutter (Dart)
- **State**: Riverpod
- **Local DB**: sqlite_crdt / Isar
- **Network**: LiveKit (WebRTC)
- **Protocol**: Protobuf

## 📄 License
AGPL-3.0
