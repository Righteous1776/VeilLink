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

## V0.6.0 transport and game performance

V0.6.0 improves the hot paths used by live chat and encrypted mini games without changing the wire protocol or storage schema. BLE framing now emits final wire packets directly instead of allocating an intermediate fragment graph, and send pacing combines link quality, device class, negotiated packet size and a bounded byte budget so good links can move more data per scheduling round while weak links remain conservative. Queue backpressure and the control-priority lane are unchanged.

Game history is reconstructed once per asynchronous database refresh and indexed by session instead of being rebuilt repeatedly during SwiftUI body evaluation. Targeted session lookup no longer reconstructs unrelated games, tactical movement search uses an indexed queue, and the tactical board caches its active-unit and legal-destination lookup for each render pass. The board also gains a clearer turn-status rail, lightweight selection lift and legal-area tinting that respect reduced-motion and legacy-device budgets. Protocol 4, VLGM1 v1 and SQLite Schema V8 remain unchanged. Actual Bluetooth throughput still depends on ATT negotiation, radio conditions and iOS scheduling.

## V0.7.0 link intelligence and game continuity

V0.7.0 makes live BLE state visible without changing the transport protocol. VeilLink now keeps a throttled per-peer link snapshot covering RSSI/quality, connection intent, reconnect attempts, ATT packet width and queue pressure. Nearby cards and Settings surface this state, and a privacy-safe diagnostics report can be copied without message content or cryptographic material.

Encrypted mini-games now bind their link banner to the actual conversation peer instead of any connected BLE peer. The most recent authenticated transport mapping is retained in memory during reconnects, the latest local game event shows queued/sending/delivered state, and a known opponent link can be refreshed in place. Protocol 4, VLGM1 v1 and SQLite Schema V8 are unchanged.


## V0.7.1 tactical situation awareness

V0.7.1 deepens 三国兵棋 without changing its deterministic rules or VLGM event format. The battlefield gains local-only 战场/补给/威胁/目标 situation layers, supply-path and command-radius analysis, objective pressure, richer counter inspection, and guest-side board orientation with labels kept upright. Attacking an enemy counter now opens a compact combat forecast first: VeilLink enumerates all 36 possible d6-vs-d6 pairs under the existing terrain, supply and command modifiers, then asks for explicit confirmation before emitting the same encrypted move event used by prior versions. Historical tactical sessions therefore rebuild to the same board states and outcomes. Protocol 4, VLGM1 v1 and SQLite Schema V8 remain unchanged.

## V0.7.2 tactical render and transport pipeline

V0.7.2 focuses on frame stability and encrypted transfer efficiency. Every 三国兵棋 render now derives unit placement, supply, command zones, objective pressure and both factions' threat maps from one immutable situation snapshot. Cached neighbor/distance tables and equatable hex cells reduce repeated rule scans and unnecessary SwiftUI redraws, while the threat layer distinguishes overlapping fire coverage without changing combat outcomes or network events.

BLE framing now appends final wire packets directly into each peer's persistent control/bulk queue. This removes a temporary packet array plus a second byte-count pass for every encrypted envelope and attachment chunk; the existing framing v2 bytes, queue backpressure, control priority and reliability policy remain intact. Protocol 4, VLGM1 v1 and SQLite Schema V8 are unchanged.

## V0.8.0 local agent foundation

VeilLink now has a fourth first-class local section, **灵核**, between Nearby and Settings on both phone and iPad. The new Agent platform is deliberately modular and lazy-loaded: V0.8.0 uses an offline deterministic Foundation Mock to validate streaming, cancellation, lifecycle, capability profiles and privacy-safe diagnostics before a real local text model is selected. No cloud API, MaleCNS graph, protocol change or database migration is included in this checkpoint. The MaleCNS research path is independently provenance-locked to `alextitonis/fly.ai` + official MaleCNS v1.0, with `Jhongdlp/FlyBrain` retained as a secondary game-integration reference only.

## V0.9.0 multimodal Agent training foundation

V0.9.0 extends the local **灵核** Agent with an offline video-conversation path and a reproducible training carrier. Front-camera frames stay local and are sampled into lightweight Vision summaries; speech recognition is used only when iOS reports an on-device recognizer, and replies can be spoken with local TTS. Gomoku, Xiangqi and Ludo now expose generic Agent observation/legal-action adapters for self-play data generation. 三国兵棋 is intentionally excluded from training until its rules are redesigned. A listwise game-policy bootstrap and GPU-oriented SHA-pinned language QLoRA workflow are provided. The completed v4 game ranker is additionally exported as a compact `VLPOL1` float32 artifact (under 1 MB) and the app now contains a read-only Swift inference runtime that can rank only engine-enumerated legal candidates for Gomoku, Xiangqi and Ludo; it cannot mutate game state and still rejects 三国兵棋. No large LLM weights are committed to the repository. Protocol 4, VLGM1 v1 and SQLite Schema V8 are unchanged.


## V0.9.1 A9 health lattice

V0.9.1 adapts the deterministic 144-state core of the earlier DBH A9 lattice into a lightweight local VeilLink health monitor. The database-oriented packet/release/contract hashes, runtime attestation envelope, Python/native `.so` path and Canonical/Freeze/Cutover semantics are intentionally removed from the A9 hot path. The Swift lattice consumes only local status telemetry from BLE link pressure, Agent runtime state, system thermal/low-power state and an on-demand SQLite integrity result, then emits an explainable GREEN/YELLOW/RED state plus advisory L0–L5 level. It has no authority to disconnect peers, mutate storage, change game state or alter trust. Existing VeilLink E2EE, attachment SHA-256, BLE integrity and storage security remain unchanged. Settings also stops running `PRAGMA integrity_check` on every redraw; the result is now cached and refreshed explicitly.


## V0.9.2 A9 compute governor

V0.9.2 repurposes the spare deterministic capacity of the A9 144-state lattice from diagnosis-only into a local **compute governor**. A9 still does not create physical CPU/GPU performance; instead it maps health/risk state plus current foreground workload into bounded budgets for MaleCNS, local language generation, Vision frame analysis, game planning and optional bootstrap training while reserving headroom for BLE transport. MaleCNS receives a stable budget contract (`suspended/lite/core`, workers, neural-step budget, episode time, rollout count and sample stride) so a future native connectome runtime can consume the same scheduler without coupling to SwiftUI or transport. Video analysis pacing and local-agent token/context budgets already adapt at runtime. Red/emergency lattice states suspend MaleCNS and background training first, preserve a minimal local-language path, and increase transport headroom under queue pressure. The governor never bypasses game legality, E2EE, iOS thermal limits or Protocol 4. The VeilFly native path now also consumes A9 worker/rollout budgets by parallelizing independent deterministic candidate episodes; ordinary decision readouts can use a low-memory mode that does not allocate a full-neuron spike histogram. SQLite Schema V8 and VLGM1 v1 are unchanged.

## V0.9.3 MaleCNS VFLY1 foundation

V0.9.3 connects the A9-governed VeilFly native engine to a versioned MaleCNS-derived graph carrier. Build-host tooling converts the pinned MaleCNS v1.0 / fly.ai reference into `VFLY1`, verifies counts and source hashes, and can derive deterministic graph-guided Core/Lite tiers. iOS now has a SHA-verified VFLY1 loader, stable sensory/readout group ports, a deterministic stimulus encoder, and lazy bundle loading that prefers Lite on legacy devices and Core on stronger devices. Raw Feather/NPZ data is never parsed inside the app. The current ChatGPT container cannot download the 260 MB/1+ GB upstream assets, so full-real-graph execution remains a heavy Work/build-host gate rather than a fabricated claim. Protocol 4, VLGM1 v1 and SQLite Schema V8 are unchanged.

## V0.9.4–V0.9.6 diagnostics and real local AI

These cumulative checkpoints add privacy-safe deep telemetry, repeatable device burn-in diagnostics, embedded SHA-verified VeilFly Core/Lite graphs, the pinned local Qwen/llama.cpp build path, learned MaleCNS readouts, legal-action game reranking and an explicit AI Control Center. Automatic context excludes chat plaintext and secrets; conversation text enters only through an explicit local assistant action. Mutating tools and suggested game moves remain permission-gated, and every game action is still enumerated and validated by the original game engine before execution.

## V0.9.7 Game Hub, local opponents and embedded icon

V0.9.7 promotes **游戏** to a first-class tab between **附近** and **灵核**. The standalone lobby supports offline single-player Gomoku, Xiangqi and Ludo against the bounded local policy, plus the existing nearby E2EE game flow. MaleCNS may rerank only legal candidates when its verified runtime is available; otherwise play falls back to the deterministic baseline policy. 三国兵棋 remains nearby-player only until a dedicated tactical policy passes its own release gate.

Build 41 also embeds the creator-provided VeilLink artwork as a complete RGB/no-alpha iPhone, iPad and App Store icon catalog. The hidden App easter egg remains present and intentionally undocumented. Protocol 4, VLGM1 v1 and SQLite Schema V8 remain unchanged.
