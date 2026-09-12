# VeilLink V0.3.6-dev architecture

VeilLink is an offline nearby E2EE messenger for iOS 15+. Runtime communication uses CoreBluetooth; ZIPFoundation is used only for local backup packaging.

## Trust and cryptographic boundaries

1. BLE advertisements expose only the VeilLink service UUID and transport name, never usernames, contacts, plaintext, or private keys.
2. Each local identity has an Ed25519 signing key. The stable identity ID is derived from SHA-256 of the public key.
3. Every live session uses a fresh X25519 ephemeral key and signed random nonce. Both signed hellos form a deterministic protocol-v4 transcript.
4. The shared secret derives a session root key. HKDF then derives distinct direction keys (`A→B` and `B→A`), preventing reflected ciphertext from being accepted as peer traffic.
5. A six-digit SAS is derived from the root key and transcript. A contact becomes trusted only after human comparison.
6. Text, attachment chunks, attachment checkpoints and ACKs use ChaCha20-Poly1305 with authenticated context, message ID, and sequence number. Their domain-separated ciphertext classes are not interchangeable.
7. A 64-position replay window accepts limited out-of-order delivery while rejecting duplicates and stale sequences.
8. Long-term secrets and storage keys remain in iOS Keychain. SQLite message bodies and attachment files are encrypted independently at rest.

## BLE transport

Both devices can act as CoreBluetooth central and peripheral. A custom GATT service carries UUID-indexed fragments. Reassembly is bounded by fragment count, packet size, total assembled bytes, concurrent partial messages, and expiry time.

Backpressure queues are isolated per peer. A packet queued for one subscribed central is never later broadcast to all subscribers. Disconnects discard session-encrypted transport queues and notify the session layer so a reconnect creates a fresh handshake.

CoreBluetooth restoration and `bluetooth-central` / `bluetooth-peripheral` background modes are enabled, but VeilLink does not claim daemon-like persistence. iOS may throttle scans or suspend execution, and force-quitting can prevent relaunch. Durable application-level work therefore lives above the BLE layer.

## Durable message delivery

Outgoing content is first written to encrypted local storage and inserted into `outbound_queue`. When a trusted peer has an authenticated live session, VeilLink creates fresh session ciphertext and hands it to BLE. Missing ACKs cause timed retransmission with backoff. Reconnects create new session ciphertext for the same stable message ID. The receiver treats that ID idempotently, stores the message only once, and still returns a fresh authenticated ACK.

Protocol 4 images use a small authenticated manifest plus independently authenticated 48 KiB chunks. The transfer layer accepts JPEG, HEIC and PNG; RAW/DNG/ProRAW and other decodable source formats are normalized before this boundary. The receiver persists chunks encrypted at rest and returns an authenticated `nextIndex` checkpoint. Only receiver-confirmed progress advances the sender. If BLE disconnects, either app relaunches, or a checkpoint is lost, the next authenticated session resumes from persisted receiver state. Final assembly is accepted only after byte-count and SHA-256 verification. Incomplete receive state expires after seven days, with a global limit of 16 and a per-sender limit of 4 unfinished attachments. Active outbound image plaintext is cached only in a bounded 12 MiB in-memory LRU-style cache to avoid repeatedly decrypting the same encrypted-at-rest attachment for every chunk.

Outbox records expire after seven days in the current development policy and then become failed. This policy is expected to become user-configurable later.

The legacy `pending_packets` schema from V0.1 is retained only for migration compatibility and is not used for resumable delivery because session ciphertext must not survive a session rekey.

## Persistence and backup

SQLite runs in WAL mode with foreign keys and indexed message/conversation access. V2 backup uses an independent backup password and includes all local identity private keys/password verifiers, active-identity state, wrapped database storage key, consistent SQLite snapshot and encrypted attachments.

Restore validates KDF bounds before expensive derivation. It snapshots database state and creates an encrypted identity rollback bundle before mutation. If any later stage fails, database, storage key, identity Keychain state and attachments are restored together.

## App lock and startup failure

Application-lock brute-force state is persisted so relaunching does not reset rate limits. If the primary database cannot be safely opened/migrated, startup presents a failure screen instead of silently deleting or replacing data.

## Owner Mode boundary

Owner Mode is a diagnostic/governance surface, not a decryption backdoor. Local authorization expires after 20 minutes. Signed tokens are device-bound, expiry-bounded, and may request only allow-listed safe capabilities. Owner Mode cannot read private-message plaintext, export peer/private keys, bypass the app lock, or execute arbitrary code on another device.


## V0.3.2 reply and local conversation search

- Text replies remain Protocol 4 text messages. A readable `↪︎「quote」\nreply` envelope lets V0.3.2 render a structured quote card while older clients still display understandable text.
- Reply quotes are normalized and capped at 160 characters; replying to an existing reply quotes only its newest reply body, avoiding runaway nesting.
- Conversation previews store only the new reply text (`↪︎ reply`) while the encrypted message body keeps the full readable reply envelope for retransmission and remote rendering.
- Conversation search runs only over already-decrypted in-memory messages; no plaintext FTS/search index is persisted to disk.
- Protocol 4 remains unchanged. Schema V8 adds local conversation pinning and activates persisted unread/read state.

## V0.3.1 local controls and transfer lifecycle

Schema V7 adds a local-only `is_paused` flag to `outbound_queue`; Protocol 4 and all cryptographic domains remain unchanged. Pausing an outgoing image removes it from due-send selection while preserving its receiver-confirmed `attachment_next_chunk`. Resume clears the pause flag and continues from that checkpoint. Cancel removes the local outbox row and marks the local message as cancelled; it does not claim to erase chunks already authenticated and stored by the peer. Authenticated checkpoints that arrive after a local cancel/delete are ignored as late completion traffic instead of being misclassified as malformed BLE input.

Local message deletion and conversation clearing are device-local operations. They cascade SQLite queue/transfer rows through foreign keys, delete referenced encrypted attachment files, and repair the conversation preview without changing peer trust. Sender-scoped tombstones are retained for eight days so an ACK-lost retransmission cannot recreate a locally deleted incoming message during the seven-day sender retry window. Incomplete inbound images are protected from deletion/clear until final integrity validation. The received-image auto-save preference is off by default and invokes PhotoKit only after the attachment has passed byte-count and SHA-256 validation.

## Remaining acceptance work

- Run build + XCTest on current Xcode/iOS SDKs.
- Execute two-real-iPhone BLE interoperability and background-restoration tests.
- Fuzz wire envelopes, fragment assembly, restore archives and malformed database inputs.
- Add persistent contact blocking/untrust and identity-switch session invalidation.
- Keep arbitrary-file transfer separate from the image pipeline. Image inputs now use a 1.8 MB quality-oriented soft target and 3 MB hard protocol limit; larger general files still need a separate policy and per-chunk integrity design.
- Review database migration policy before any stable release.
- Conduct independent protocol/security review before any high-risk use claim.


## BLE transport safety limits

Transport v2 preflights fragmentation before allocating packets. Protocol 4 envelopes are capped at 96 KB, so the live transport accepts at most 16,384 fragments per envelope (enough for the Bluetooth LE legacy 20-byte ATT value path) rather than exposing the raw UInt16 maximum to runtime queues. Per-peer outbound queues are capped by packet count and encoded bytes. Receive reassembly is capped at 96 KB per frame, 768 KB globally, 32 concurrent frames, and 8 incomplete frames per BLE source; buffered-byte accounting is O(1) and one source cannot consume every reassembly slot. Repeated invalid envelopes are windowed per transport and only the offending BLE link is disconnected after the threshold.

## V0.2.3 session consistency

CoreBluetooth can report progress through multiple delegate callbacks. Central-side readiness is published only after the data characteristic exists and notification subscription succeeds; `ConnectionEventGate` then turns readiness into one logical connected/disconnected transition per transport ID, and `SessionCoordinator` independently ignores duplicate connected callbacks. A pre-authentication session is bounded to 15 seconds; successful Hello authentication cancels the deadline, while expiry removes the incomplete session and disconnects that BLE transport. Message insertion and conversation preview advancement share one SQLite transaction. Attachment file creation is rollback-safe with respect to its database row: if the row insert fails, the just-written encrypted file is deleted.


## V0.3.3 visual and motion layer

- `Core/AppTheme.swift` owns the reusable visual tokens and presentation primitives.
- UI motion is state-driven rather than decorative: message insertion, reply/search surfaces, button press feedback, transfer progress and active BLE scanning.
- `accessibilityReduceMotion` disables or simplifies non-essential movement.
- Visual changes do not enter the wire codec, session crypto, reliable delivery semantics, media checkpoint protocol or database schema.


## V0.3.4 visual identity layer

The UI derives a non-security visual glyph from each identity ID for local recognition. This representation never participates in trust decisions; SAS verification and pinned Ed25519 identity material remain authoritative. The UI uses asymmetric cut panels, broad dark veil planes, state-bound Link traces, and short Resolve animations. Motion is visual feedback only and cannot advance protocol or delivery state.


## V0.3.5 tactile and conversation-state layer

`HapticEngine` is a UI feedback boundary only: it never drives transport, trust, delivery, or cryptographic state. It is preference-backed, disabled outside the active app state, and maps interaction semantics to selection / impact / resolve / warning feedback. Delivery haptics are emitted only after an authenticated ACK/checkpoint changes an outgoing message from a non-delivered state.

Schema V8 adds `is_pinned` to conversations. Pinning affects only local ordering. `unread_count` now increments atomically in the same message/conversation transaction for newly persisted inbound messages and remains unchanged for outgoing messages. Opening a visible conversation clears its unread count; users may also mark a conversation read/unread explicitly. None of these fields are transmitted to peers.

Local CI simulation validates manifests, all Swift syntax, Linux-compatible core typechecking, iOS 15 API guards, migration semantics, shell scripts and IPA archive layout. Final acceptance still requires macOS XcodeGen + Xcode Simulator XCTest + unsigned iphoneos Release build.


## V0.3.6 runtime optimization layer

V0.3.6 keeps Protocol 4 and Schema V8 unchanged while reducing hot-path work. BLE reassembly now uses typed keys, per-source partial counts, and throttled stale pruning, reducing per-packet bookkeeping without changing the wire format. Attachment progress notifications are emitted only when persisted progress actually changes, conversation-list refreshes are separated from message-only refreshes, accepted outbound retry scheduling uses one SQLite UPDATE instead of SELECT+UPDATE, and V8 adds non-destructive lookup indexes for conversation peers and attachment message joins.
