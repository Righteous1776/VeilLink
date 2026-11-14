# VeilLink Diagnostic Flight Recorder R2 — Global Coverage / Five-Night Evidence

## 1. Why V1 is insufficient

V29.1 Build 67 contains a working DiagnosticLogStore, DeepTelemetry and MetricKit, but the prior candidate's 192 MiB budget has no demonstrated five-evening coverage. New VeilLink modules are not automatically instrumented merely because UI and global touch probes exist. Consequently, **coverage completeness** and **retention completeness** must be audited independently. Never claim arbitrary iOS process or private system-log access.

Assumption used only for sizing illustration: five nights × three hours = 15 active hours. 512 MiB / 15 h ≈ 9.7 KiB/sec average. It is a target budget, not measured event throughput and NOT a guarantee of five nights.

## 2. Actual staged code proposal (PATCH.diff)

**512 MiB configured budget:** 24 × 16 MiB JSONL segments (384 MiB) and 128 MiB auxiliary; auxiliary file cap 32 MiB / 96 files; in-memory last 6,000; pre-consent fixed schema 512. Pending 4 MiB RAM buffer and post-successful-append rotation are deliberately preserved. No new permission or background mode is declared.

**Retention evidence:** Count and persist the number of overwritten oldest segments in `retention-evictions.json`; include `rotationEvictionCount` and `retainedTimeSpanHours` (actual earliest/latest captured timestamps from export) in the ZIP manifest. Provide owner-visible disk utilization and eviction count. If either the span is short or evictions occurred, do not call the archive a complete multi-night record.

**Content-free UI chronology:** ChatView's actual visible row order is captured via ephemeral per-session tokens, ordinal, direction, delivery state, timestamp, attachment presence and non-plaintext flag. New observations are deduplicated; no message body, search phrase or persistent message IDs are exported by this channel.

**Feature evolution:** `VeilFeatureLibraryView` automatically emits an inventory for the existing `VeilFeatureRegistry` on open and reports a typed `feature.open` checkpoint. The export index records `registeredFeaturePacks`, `moduleCheckpointCounts`, and `unobservedRegisteredPacks`. A new feature registered here will appear in this inventory without editing the recorder. A pack missing an event is described as *not observed during this capture*, not necessarily uninstrumented or broken.

**Integration API:** `RuntimeDiagnosticsBridge.recordModuleCheckpoint(module:phase:counters:flags:level:)` accepts only identifier-shaped module/phase strings and integer/Boolean telemetry. Future BLE/LAN/Relay/Community/Game/Agent/Storage/AI lanes should emit checkpoints on lifecycle, enqueue, retry, timeout, failure and recovery. This is opt-in per module; no reflective or private UI scraping.

**Owner controls:** Add explicit “开启全部本机诊断采集” in the existing owner-protected console; it enables four already supported in-app DeepTelemetry categories (raw touch, input lifecycle without text, post-interaction UI hierarchy metadata, performance). It does not acquire OS or other-app privileges; switches stay on until the owner disables them.

## 3. Permission model, bounded by reality

| Scope | Implementation | Permission |
|---|---|---|
| App lifecycle, own UI and bubbles | Current app-owned events and new typed checkpoints | Within app, with owner settings where sensitive |
| BLE/LAN/Relay internals | Add module-specific state counters and correlation IDs | Only own transport state, no captured user payload |
| Own SQLite migrations/error codes | Add typed step/failure events; no table dumps | Sandbox data only |
| MetricKit crash/hang/energy | Existing MetricKit integration, OS delivery scheduling | Official OS API, no guaranteed immediate full history |
| Keychain/identity | Log access outcome/error *codes*, never secret values | Existing scoped app authorization |
| Other applications / system-private logs / sandbox escape | Not included | Not granted; no bypasses or privilege escalation |

## 4. Follow-on integration milestone: not falsely claimed as implemented

A five-night guarantee **cannot** be promised from a 512 MiB circular JSONL store. Before release, implement and validate: (A) daily partitions or archived segments with age-aware eviction; (B) stream-compressed cold segments and integrity checks; (C) incident-priority reserve to prevent routine high-volume UI events erasing crash causality; (D) bounded volume telemetry per subsystem with visible suppression/drop counters; (E) segment-by-day export instead of one enormous ZIP; (F) time-coverage and free-space forecasting from measured foreground write rate; (G) module-specific coverage obligations plus CI check for every newly added feature. Consider owner-configurable 1 GiB only after actual storage/power measurements.

No benchmark has established the 512 MiB budget will last five nights, so the product must label retention completeness honestly and allow export after sessions.

## 5. Compatibility and release governance

Zero database/wire/crypto migrations. Existing diagnostic JSONL v2 keeps its schema. Only new optional export metadata and additive feature checkpoints are proposed. Main remains unchanged; PR #222 is INBOX_ONLY, Draft; no release/IPA has been triggered.


## R3 ADDENDUM — Actual module-level instrumentation (2026-11-14)

This revision implements proposed **typed capture at real product state-machine boundaries**, not just a game screen opening. PATCH.diff now contains **14 source/test files**. All writes remain proposals inside the Inbox only.

### Native local game controller (all 7 MiniGameKind cases)
In `LocalAIGameController`, emit `diagnostics.module.checkpoint` with `module=game.<kind>` for match restart, accepted human/AI turns, AI search begin/end, match outcome changes, match save failure and Gomoku native self-play training begin/saved/finished. For Gomoku/ECLIPSE capture accepted 0–224 board cell index, ply count, seven-tier *compute budget multiplier* and decision duration (ms); never claim 6x Elo or log board screenshot/search payload/learning archive. Other six reducers get accepted turn/outcome/AI execution lifecycle, without storing full state or private text.

### BLE transport
Direct low-level events use `ble.flight.*`, emitted where the transport actually changes state: explicit connect/disconnect/recover, physical connected/disconnected, GATT data channel ready/lost, reconnect attempt/delay, connection errors as codes, and congestion in both central/peripheral queue admission. Congestion reports are throttled to one per five seconds to protect multi-night retention; this is **sampling**, not exact suppressed-event accounting. Packet bytes themselves are never captured. Existing GATT timeout instrumentation and RuntimeDiagnosticsBridge snapshot logic remain.

### Veilopoly multiplayer
Inside `VeilopolyMultiplayerBridge`, capture invitation lifecycle, accepted/declined invitation actions, decoded-control packet observation by fragment count (not packet bytes), invalid packet, room create/restore/leave, queue full/queued/sent/send failure, manual resync and identity-switch suspension. A Combine observation on `GameSessionModel.$game` adds deduplicated committed reducer state (sequence, player seat, player count, finished flag) and explicitly cancels when leaving or suspending the room.

This records critical real multiplayer behavior but **does not yet provide per-action economic engine telemetry** (buy/build/trade/auction/stock/bank/AI turn logic), nor does the offline Veilopoly game's reducer expose a host diagnostic hook. Those must be instrumented at `VEILOPOLY_DEV/Veilopoly/Sources/VeilopolyUI/UI.swift` or via an injected app-host observer while keeping SwiftPM module independence; no fake subsystem-wide completeness claim.

### Real-time and story games
`GameLobbyView` records game-lobby entry and `screen.open` for fourteen real arcade/story routes: PrismRift, Afterglow Convoy, Ash Harbor, Rainline, Signal Dive, Blackout District, Pulse Runner, Void Swarm, Rhythm Neon, Rhythm R6, Lattice Clash, Story Lab and two Monogatari routes. Each game's physics/render tick, spawn/damage/score, collisions, loading, save/checkpoint and low-frame-rate events still require separate typed hooks. **An entry event is launch coverage only.**

### Ongoing integration rule
Every new feature must declare its **coverage tier**: `ENTRY_ONLY`, `LIFECYCLE`, `STATE_MACHINE`, `DEEP_DIAGNOSTICS` or `UNOBSERVED`. A feature registry count does not certify any deeper tier. Before promoting an extension, verify the same scenario's trace contains a start, transitions, success/failure, and cleanup event with shared correlation token. Add invariant tests for all modules and a coverage gate in integration CI. Do not store chat text, packet contents, private credentials or cross-app telemetry.

### Five-evening storage
Retention remains a configured 512 MiB ring, **not guaranteed five-day coverage**. Expected rates require measurement in real evening sessions, accounting for controller training and BLE reconnect bursts. Compression/age-partition/high-priority reserves/daily export remain future engineering gates.

## R4 — real game subsystem collection added

The proposal now hooks **actual state changes**, beyond the previous feature-library and game-lobby activation events:

1. **Five-in-a-row/ECLIPSE & local AI:** LocalAIGameController records accepted Gomoku moves (board-cell index and ply count), AI search begin/end and duration, successful result transitions, native self-play training milestones, and local save errors. The other six shared-controller games emit accepted-turn and search-completion checkpoints. No full replay, imported training content or persistent match IDs are included.
2. **Bluetooth:** BLETransport records connect/recover/disconnect intent, physical and logical data-link transitions, scheduled reconnect delay/attempt, numeric connection-failure codes and throttled queue-pressure counters. It never adds packet ciphertext/plaintext, session keys, peer identities or raw advertisement payloads. Existing link snapshots remain available for queue depth, stage and quality.
3. **Veilopoly multiplayer bridge:** user invitation, accept/decline, room creation, packet submission and receive, synchronization and recovery failures, bounded control queue saturation. Control payload is never captured.
4. **Veilopoly engine, including solo mode:** a fixed primitive-only NotificationCenter contract from isolated `VeilopolyUI.GameSessionModel` records reducer commit/reject, new/resumed match, save unavailable/failure and validated network snapshot. The main app validates an event allowlist plus a finite set of turn-phase states and translates them into typed diagnostic checkpoints (including phase code). It never transfers a card, move payload, game seed, player name, finance amount or room ID. Automatic high-frequency stock-market clock ticks are excluded.
5. **Real-time games:** Rainline, Afterglow, SignalDive and Blackout record transitions of fault count, repair count, recovered items, node power, terminal outcome reason, plus a coarse 30-second tick window. LatticeClash records committed human move cell and AI response count; Prism Rift records discrete impacts, collections and boss/terminal events while omitting per-laser and per-render-frame events. These are sparse diagnostics, not all individual simulation steps.
6. **Other arcade and story modules:** 14 additional game/experience entries in GameLobbyView have launch checkpoints, but their internal engines still need dedicated hooks and tests in a later integration lane.

An on-device owner's diagnostic authority applies to owned application modules only; this submission does not request private iOS permissions, root or data from other apps. The five-evening preservation claim **still requires measured runtime/event write rates plus compression/age policies and physical device export tests**. No hidden sources or future features are declared fully covered.

### Integration prerequisites

- Verify SwiftUI/Swift Package (VeilopolyUI) compatibility and Checkpoint event delivery before enabling full runtime traces.
- Add per-engine crash/transaction/recovery hooks where this patch records only sparse milestones.
- Mark diagnostics coverage distinctly: `full internal`, `partial`, `entry only`, `unobserved`; observed event count is **not** proof of module completeness.

## R5 — repair UI touch black-box observability

### Evidence from current source

`DeepTelemetry.rawTouchCaptureEnabled` defaults to `false`. The original `UIInteractionProbe.sync` adds a custom `PassiveTouchRecorder: UIGestureRecognizer` only to visible windows at install/reactivation or explicit toggle; it reports after a touch ends, then forces the recognizer state to `.failed`. This is not a reliable proof of complete window coverage; later windows, overlays and some SwiftUI gestures may be missed. This is a code-path diagnosis, **not** a physical-device reproduction.

### Proposed implementation in PATCH.diff

- Register a `UIWindow.sendEvent(_:) ` event interceptor *once*, using the existing app's Objective-C method-exchange approach. Invoke the original event dispatcher unconditionally; never consume, cancel or delay user touches. No additional `UIGestureRecognizer` is installed. Runtime interception requires on-device compatibility testing.
- Observe only visible, app-process application/overlay windows with a root controller in expected window levels, excluding known system keyboard/text-effects/remote windows. Track `UITouch` object identity per active gesture and produce a single concise end-of-gesture record; include touch count, tap/long press/swipe/multitouch, duration, displacement, view class/ancestry, and non-sensitive coordinates when permitted.
- Never record keyboard-window touches. Redact coordinate, frame, accessibility ID and text-input length if keyboard is displayed, any text input has focus, the touched view is a text entry, or a secure screen is active. Do not keep `UIView` instances in the active-touch tracker. The existing `ui.raw.*` event schema remains compatible with prior diagnostic export.
- Persist only captured events through existing DiagnosticLogStore. Keep raw touch default **off** until Owner explicitly opts in; no secret self-activation. Report `ui.touch_probe.status` on installation/enable transitions with a `ready`/ `enabled` flag and stable capture source identifier.
- Show clear status and `capturedTouchCount` in the Owner diagnostics card. A user can turn the switch on, tap in the same page and verify the counter increments. This is a self-test indicator, not a claim of 100% touch coverage.
- Add pure-policy XCTest `DeepTelemetryTouchProbeTests` covering gesture categorization, app overlay versus keyboard/system windows, and suppression of coordinates on password/input/keyboard contexts.

### Result and limitations

Provides a more direct instrumentation boundary for scrolling, button taps and multi-touch on application windows while avoiding gesture-recognizer interference. Does not capture external apps, iOS system touch streams, typed characters or pixel/screen recordings. Method swizzling is a compatibility risk; simulator and device acceptance gates are mandatory. Optional window subclass alternatives should be considered if UIKit interception breaks any platform. The earlier 512 MiB five-night retention and other R4 game/transport hooks are unchanged.
