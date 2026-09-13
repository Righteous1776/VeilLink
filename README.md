# VeilLink

VeilLink is a GitHub-buildable iOS 15+ prototype for nearby, serverless encrypted
messaging over Bluetooth Low Energy. The UI is Chinese-first and adapts separately
to compact iPhone screens and regular-width iPad layouts.

## Included in V0.1

- SwiftUI phone tab layout and iPad sidebar/detail layout.
- Up to five local cryptographic identities.
- Six-digit app lock with Touch ID / Face ID fallback.
- CoreBluetooth central + peripheral discovery and state restoration.
- Signed identity hello, ephemeral X25519 handshake and six-digit verification.
- ChaCha20-Poly1305 encrypted text packets with replay counters.
- Fragmented BLE GATT transport with flow-aware queues and resumable JPEG / HEIC / PNG transfer.
- SQLite WAL storage with encrypted message bodies.
- Password-encrypted ZIP backup and rollback-first restore path.
- Hidden black-and-gold Owner Mode with expiring, privacy-bounded capabilities.
- GitHub Actions workflows for simulator compilation and unsigned IPA packaging.

The current V0.2 engineering checkpoints additionally add compact binary envelopes,
bounded BLE reassembly/queue memory, persistent outbound resend with authenticated
ACK handling, explicit delivery failure reasons, manual retry, and Protocol 4
receiver-confirmed resumable image transfer. V0.2.2 further tightens runtime stability with
96 KB wire-aligned BLE reassembly budgets, per-source invalid-packet isolation, batched
SQLite maintenance, and self-healing completed-attachment state. Images are split into
authenticated 48 KiB application chunks whose encrypted checkpoints survive disconnects
and app relaunches. The transfer UI now uses checkpoint-driven shard animation: the sender's
local photo fragments as confirmed chunks leave, while the receiver assembles an
encrypted shard field and reveals the real image only after integrity validation.

V0.3 adds local contact aliases and identity deletion, then V0.3.1 adds device-local
message deletion / conversation clearing, persistent pause-resume-cancel controls for
outgoing images, and an opt-in setting to save fully verified received images to Photos.
Protocol 4 is unchanged; the local SQLite schema is V7.
V0.3.4 establishes VeilLink's own visual identity instead of a generic black/gold skin. Identity IDs now derive deterministic local visual glyphs; broad near-black "veil" planes create depth without bright glass effects; asymmetric cut panels replace most generic rounded cards; and motion is constrained to three meanings: Reveal, Transit, and Resolve. Conversation headers, peers, settings, lock/onboarding, transfer surfaces, and iPad navigation share the same language. Protocol 4 and Schema V7 remain unchanged.
V0.3.9 keeps the V0.3.8 iOS 15 layout stabilization and adds a performance overhaul aimed at A10-era devices: normal chat rendering decrypts only a bounded recent window off the main thread, immutable message bodies use a bounded decrypted-text cache, image bubbles use ImageIO downsampled previews with an NSCache instead of full-resolution UIImage decoding, inbound attachment finalization reads/decrypts all persisted chunks with one prepared SQLite statement and one SHA-256 pass, and iPhone 7 uses a lower-cost shard animation path. Protocol 4 and Schema V8 remain unchanged. V0.3.10 then specializes those budgets for the actual deployment devices: SE1, iPhone 7/7 Plus, SE2 and iPhone 13 Pro each receive different message-history, image-cache, BLE-memory, refresh and transfer-rendering budgets. Memory warnings actively release transient caches, A9/A10 devices trim them on background, and the decrypted-message cache evicts incrementally instead of periodically flushing everything. iPad Air 4 remains a tracked experimental target with known UI defects intentionally deferred. V0.3.11 keeps those automatic profiles as the safe default but adds an authenticated Owner Mode performance switchboard: local-only toggles can lift image-preview resolution, attachment-cache, refresh-coalescing and visual-motion limits when explicitly requested, with a deliberately theatrical high-risk preset and a one-tap return to automatic policy.

Multi-hop relay, signed Owner token generation, and full on-device BLE testing
remain for later iterations. Their boundaries are already represented in the
architecture.

## Build entirely on GitHub

1. Create an empty GitHub repository and upload this project.
2. Keep the default branch named `main`.
3. Open **Actions → iOS CI → Run workflow**.
4. The workflow installs XcodeGen, generates `VeilLink.xcodeproj`, resolves the
   package dependency, and compiles against an iOS simulator SDK.
5. Run **Build unsigned IPA** to receive `VeilLink-unsigned.ipa` as an artifact.

The unsigned IPA verifies device compilation but cannot be installed directly on a
normal iPhone. Installation requires an Apple-issued development/distribution
certificate and matching provisioning profile. Never commit certificate, profile,
or private-key files to GitHub; the repository ignores their common extensions.

## Local Mac build, if available later

```sh
brew install xcodegen
xcodegen generate
open VeilLink.xcodeproj
```

## Security status

This is an engineering prototype, not an independently audited cryptographic
product. Do not represent V0.2 as suitable for high-risk communications until the
protocol, key lifecycle, restore path and real-device BLE behavior have been tested
and reviewed.

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for the protocol boundaries.

## Image import and photo export

VeilLink accepts common image files plus RAW / DNG / ProRAW when the current iOS decoder supports them. Large or RAW inputs are processed off the main thread, capped to 4096 px on the long edge, encoded as high-quality HEIC when available (JPEG fallback), and kept near a 1.8 MB soft target with a 3 MB protocol hard limit. Small JPEG/HEIC files and lossless PNG graphics can be preserved without re-encoding. Received JPEG/HEIC/PNG attachments can be written to Photos through PhotoKit after explicit add-only permission.

V0.3.12 adds an entirely local full-screen image viewer for verified chat attachments. Tapping an image opens a black full-screen canvas with pinch zoom up to 5×, double-tap zoom, panning while zoomed, and swipe-down dismissal at 1×. Chat bubbles keep device-budgeted thumbnails; the viewer performs a separate on-demand ImageIO decode sized for the actual deployment devices (1536 px SE1, 2048 px iPhone 7, 2560 px SE2, 3072 px iPhone 13 Pro / iPad Air 4, or 4096 px only when the Owner Mode high-definition override is explicitly enabled). Source attachment bytes remain encrypted at rest and are never sent anywhere for viewing.


## V0.3.13 BLE reliability

V0.3.13 focuses on real-device reliability for SE1, iPhone 7, SE2 and iPhone 13 Pro. The transport now refreshes/smooths RSSI, paces packet bursts more conservatively as the link becomes marginal, prioritizes handshake/ACK/checkpoint/text traffic ahead of bulk image fragments, reconnects indefinitely with capped backoff while the user still wants the link, and detects stalled send queues. The secure Hello is retried idempotently and pending outbox rows are woken immediately after a trusted session re-authenticates. Messages no longer fail merely because a noisy link passed ten send attempts; the existing persistent outbox expiry is the final bound. This improves eventual delivery but does not claim a guaranteed number of meters, because iOS scheduling, obstruction and 2.4 GHz interference remain physical constraints. Protocol 4 and Schema V8 are unchanged.

## V0.4.0 encrypted mini games

V0.4.0 adds a two-player Game Hub inside trusted conversations. Gomoku, Chinese chess, and a lightweight two-player Ludo mode reuse the existing end-to-end encrypted message channel: invitations, acceptance, moves and resignation are compact structured chat payloads protected by the same session encryption, replay window, ACK/outbox retry path and reconnect behavior as normal messages. Game state is reconstructed from encrypted conversation history, so Protocol 4 and SQLite Schema V8 remain unchanged and no parallel game database is required.

## V0.4.1 game experience overhaul

V0.4.1 hardens the encrypted mini-game layer before remote release. Game reconstruction now ignores pre-accept moves, collapses duplicate/conflicting turn actions deterministically, supports cancelling pending invitations, recognizes full-board Gomoku draws, and ends Chinese chess when the side to move has no legal action while surfacing check state. The UI replaces dense button grids with real intersection-based Gomoku and Xiangqi boards, adds last-move/winning-line/legal-destination guidance, a visual two-player flight track, rules sheets, rematch, turn haptics and low-cost motion that respects reduced-motion/legacy-device budgets. Normal chats now show one live encrypted game card per session instead of either hiding invitations or flooding the transcript with move payloads. Protocol 4 and SQLite Schema V8 remain unchanged.

## V0.4.2 game polish & replay

V0.4.2 turns the encrypted mini-game layer into a more persistent social surface without changing the wire protocol or database. Finished games can be replayed step-by-step from the same encrypted chat events that reconstruct the live board; the Game Hub derives local win/loss/draw statistics and win streaks from completed sessions; match duration is reconstructed from invite/accept/activity timestamps; and attempting to start a second live copy of the same game now reopens the existing session. Ludo also gains a deliberate roll-then-move interaction so the turn feels like a game instead of exposing the deterministic result immediately. Protocol 4, VLGM1 packet version 1, and SQLite Schema V8 remain unchanged.

## App easter egg

The creator left a hidden easter egg inside VeilLink. Its trigger and contents are intentionally undocumented—explore the app to discover it.

作者在 App 里留下了一个隐藏彩蛋。这里仅确认它存在，触发方式与内容留给你在应用中发现。

### V0.4.3 game fair-play hardening

V0.4.3 keeps the game transport and storage model unchanged while tightening long-session behavior. Xiangqi now detects the same board position with the same side to move three times and closes the casual match as a draw, tracks consecutive checks for player-facing warnings, and avoids representing that simplified rule as full tournament perpetual-check adjudication. Replay can auto-advance through the encrypted-history-derived score, incoming invitations are visually prioritized, and reconstruction tests cover duplicated, delayed and reordered game packets. Protocol 4, VLGM1 v1 and SQLite Schema V8 remain unchanged.

## V0.5.0 三国兵棋 · 官渡决战

V0.5.0 adds an original two-player lightweight historical wargame to the encrypted Game Hub. `三国兵棋 · 官渡决战` uses a compact 7×9 hex battlefield, terrain movement costs, Cao/Yuan formations, two-order activations, supply tracing, command support, deterministic combat resolution and objective victory points. Tactical orders reuse the existing VLGM1 encrypted chat-event stream, so reconnect, duplicate collapse, deterministic replay, match history and statistics work without a second transport or database. The scenario is an original mobile adaptation of the general hex-and-counter wargame form; it does not reproduce a commercial map, artwork, rules text or exact unit data. Protocol 4, VLGM1 v1 and SQLite Schema V8 remain unchanged.

## V0.5.1 BLE game-link hardening

V0.5.1 prioritizes connection continuity while an encrypted game is active without changing Protocol 4 or the game payload format. A bounded control overflow lane lets handshake, ACK/checkpoint, text and mini-game events enter the transport even when bulk image fragments have reached the historical queue cap; bulk retains its original capacity so legacy attachment behavior is not regressed. Early reconnect attempts are faster, control-bearing queue stalls recover sooner, and user connection intent can survive an ordinary process relaunch through CoreBluetooth peripheral retrieval. Foreground re-entry re-arms discovery/reconnect health checks while background scheduling avoids aggressive false-positive recovery. The Game Hub now surfaces current BLE readiness. These measures improve eventual game-turn delivery but do not claim an impossible guaranteed RF connection under distance, obstruction, interference, force-quit, or iOS scheduling constraints.

## V0.5.2 local tactical rendering

The 三国兵棋 battlefield is fully install-local and code-rendered. Hex geometry, terrain marks, faction flags, and unit counters are generated from Swift/SwiftUI static blueprints that are warmed during app bootstrap. The tactical board does not depend on network assets, runtime bitmap loading, `UIImage`, or `AsyncImage`, keeping battle startup deterministic and lightweight on iPhone 7-class devices.


## V0.5.3 game UI layout hardening

V0.5.3 is a focused mini-game layout correction. The 三国兵棋 board container now derives its aspect ratio from the exact cached 7×9 hex geometry, occupied objective labels cannot spill into adjacent rows, compact attack markers stay inside SE1/iPhone 7 cells, and the Xiangqi river labels explicitly span the board width. Compact game headers use bounded single-line scaling. Protocol 4, VLGM1 v1 and SQLite Schema V8 are unchanged.
