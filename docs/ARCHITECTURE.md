# VeilLink V0.3.13-dev architecture

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

CoreBluetooth can report progress through multiple delegate callbacks. Central-side readiness is published only after the data characteristic exists and notification subscription succeeds; `ConnectionEventGate` then turns readiness into one logical connected/disconnected transition per transport ID, and `SessionCoordinator` independently ignores duplicate connected callbacks. Pre-authentication Hello delivery is now retried on an idempotent short schedule. A weak link no longer turns one dropped Hello into a permanent disconnect; the session can reseed the handshake while the physical BLE link remains alive. Message insertion and conversation preview advancement share one SQLite transaction. Attachment file creation is rollback-safe with respect to its database row: if the row insert fails, the just-written encrypted file is deleted.


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

## V0.3.7 legacy compositor layer

The visual layer includes a pure `RenderCompatibilityPolicy` plus an iOS hardware identifier bridge. iPhone 7 / 7 Plus on iOS 15 select a reduced compositor path: persistent link/radar motion is static, ambient backgrounds avoid GeometryReader-driven curtain layers, and shared card/glass modifiers avoid the heaviest clip + duplicate overlay + shadow composition. This is presentation-only and does not alter transport, protocol, trust, crypto or persistence semantics.

## V0.3.8 iOS 15 stable scroll layout

The real-device failure pattern was refined from a pure compositor-load hypothesis to a ScrollView content-host layout instability: navigation/tab chrome stayed fixed while the entire scrolling content layer shifted horizontally, clipped, disappeared and later returned. Shared affected screens used nested `maxWidth`/`infinity` sizing inside a vertical ScrollView. V0.3.8 introduces `VeilStableScrollView`, which measures the viewport outside scroll content and assigns a concrete centered content width. iOS 15 builds also expose a stable-layout diagnostic label; the iPhone 7 compositor reduction from V0.3.7 remains active.


## V0.3.9 performance overhaul

The hot path is now bounded around real screen needs rather than total history size. ChatView loads the most recent 120 messages on a background queue and expands in 120-message windows on demand; full-history decryption is reserved for an explicit search. DatabaseStore caches up to 512 immutable decrypted message bodies so delivery/progress refreshes do not repeatedly perform ChaChaPoly opens. Image bubbles decrypt original bytes only once per cache miss, then ImageIO creates a <=1024 px display preview without a full-resolution decode; previews are held in a 32 MiB cost-bounded NSCache. Inbound image finalization replaces roughly one SQLite prepare/queue hop per 48 KiB chunk with one ordered statement and an incremental SHA-256 pass, then reuses that verified digest while saving. The legacy iPhone 7 compositor path also disables shard trails, per-shard shadows and spring interpolation while preserving checkpoint-driven visual progress.


## V0.3.10 targeted device performance

`DevicePerformancePolicy` maps the small, explicit deployment fleet to local-only runtime budgets without changing Protocol 4. SE1 (`iPhone8,4`) is the constrained A9 profile; iPhone 7/7 Plus (`iPhone9,x`) use a legacy A10 profile; SE2 (`iPhone12,8`) uses a balanced A13 profile; iPhone 13 Pro (`iPhone14,2`) uses the high profile; and iPad Air 4 (`iPad13,1/2`) has a deterministic performance profile while its UI repair remains deferred. The policy controls chat history windowing, immutable decrypted-body cache size, image thumbnail resolution/cache cost, outbound attachment cache, BLE queue/reassembly budgets, message refresh coalescing, transfer visual complexity and background cache trimming. Memory warnings always clear transient caches. The cache policy is strictly local and does not alter message encoding, cryptographic domains, chunk size, checkpoint semantics or peer compatibility.


## V0.3.11 Owner Mode performance overrides

`PerformanceOverrideStore` keeps a thread-safe local snapshot of explicit developer overrides, while `PerformanceOverridePolicy` derives an effective runtime profile from the existing hardware-specific base profile. Owner Mode is the only UI surface that can edit these values. The master override is disabled by default. Optional overrides can raise local preview resolution to 2048 px, expand the in-memory outbound attachment cache to at least 16 MiB, disable message-refresh debounce, force full visual complexity, and re-enable persistent animations on SE1/iPhone 7. The override layer intentionally does not modify BLE queue/reassembly limits, Protocol 4, Schema V8, encryption, chunking or peer compatibility.

## V0.3.12 in-app image viewer

Chat image bubbles use the normal `ImagePreviewCache` device budget. Opening a large image presents `FullScreenImageViewer`, which immediately reuses the bubble thumbnail and asynchronously decrypts the local attachment and performs a second ImageIO downsample governed by `ImageViewerPolicy`. This keeps scroll-time memory cheap while allowing explicit detail viewing. The viewer owns its larger `UIImage` only for the lifetime of the full-screen presentation and supports 1–5× interaction entirely in-process.


## V0.3.13 BLE reliability layer

BLE reliability is layered rather than expressed as a distance promise. CoreBluetooth still owns the physical radio/link-layer retries; VeilLink adds live RSSI smoothing, signal-aware burst pacing, control-over-bulk queue priority, persistent capped reconnect, stalled-queue recovery and repeated Hello delivery. Persistent messages are not failed merely because a marginal link exceeded ten accepted sends: the outbox continues until authenticated ACK/checkpoint or expiry. A newly authenticated trusted session wakes old pending rows immediately. These changes leave Protocol 4 and Schema V8 unchanged and do not alter RF transmit power.


## V0.5.0 tactical game layer

The fourth Game Hub mode adds `TacticalState` and a SwiftUI hex-map renderer while preserving the existing VLGM1 envelope. A tactical move encodes only source/destination coordinates (or a reserved pass shape), and the receiver independently recomputes legal movement, supply, command support, deterministic combat rolls, objective scoring and terminal state. No combat result is trusted merely because it arrived over the wire. This keeps duplicate/reordered packet handling aligned with the existing mini-game reconstruction model. The 7×9 scenario is intentionally small for iPhone 7-class devices and avoids introducing a second persistence layer. Protocol 4, VLGM1 v1 and Schema V8 remain unchanged.

## V0.5.1 game-link connection hardening

The transport now treats control capacity as an overflow lane rather than subtracting it from the historical bulk queue budget. This distinction matters on a legacy 20-byte ATT value: a Protocol 4 48 KiB attachment chunk can consume the existing packet cap, so reserving packets by shrinking bulk would deadlock media transfer. Instead, bulk remains bounded by the original device profile and control traffic may exceed that bound only by a small fixed policy budget. Queue drains still service control before bulk. If a queue with control traffic makes no progress, its watchdog threshold is shorter than the bulk-only threshold.

Central-side connection intent is persisted as CoreBluetooth peripheral identifiers only after the user requests a connection. Startup/foreground restoration uses `retrievePeripherals(withIdentifiers:)` plus ordinary scanning to resume the desired link. Explicit disconnect or transport stop removes the stored intent. CoreBluetooth restoration identifiers and the existing background modes remain enabled. This is a resilience mechanism, not a daemon guarantee: iOS can still suspend execution, force-quit can block relaunch, identifiers can become stale, and RF conditions remain outside the app's control. Protocol 4, cryptographic framing, VLGM1 and Schema V8 are unchanged.
