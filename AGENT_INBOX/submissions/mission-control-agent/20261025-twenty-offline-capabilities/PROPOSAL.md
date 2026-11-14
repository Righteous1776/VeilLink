# Mission Control R1: twenty tangible capabilities as pure offline computation

## Objective and pre-existing feature review

The repository already contains PTT, File Integrity, JSON, QR, an encrypted message workspace, local conversion utilities, games and live BLE monitoring. These MUST NOT be counted as twenty new features. The new deliverable is a discrete Mission Control analyzer that aggregates new operational calculations and incident decisions.

## What is implemented

- Twenty real `VeilMissionFeature` enum cases, twenty result-generating switch branches, localized names and four functional groups.
- A pure Foundation engine (`VeilMissionControlEngine`) that accepts explicit `VeilMissionSnapshot` input and returns risk-labeled `VeilMissionFinding` results.
- Bounded Dijkstra path computation and node-independent backup-path computation with invalid graph rejection.
- Fail-closed diagnostic interpretation of inaccessible Keychain/SQLite conditions; NO key lookup, reset, backup restore, migration or storage writes.
- Four task categories with a SwiftUI screen and three selectable clearly synthetic scenarios: normal, weak link, recovery.
- Ten XCTest functions proposed for algorithm coverage/route correctness/safety/determinism, not yet run.
- One minimal Tool Center navigation diff adding the Mission Control entry; all new source lives under Inbox `FILES/`, not production.

## Explicitly NOT delivered in R1

- No real-time hardware API adapter or message database reader; no live RSSI/MTU/ack sample collection. Inputs are deterministic fake fixtures.
- No actual BLE/LAN route mutation, protocol feature bit change, Mesh forwarder, storage cleanup, or autonomous radio controller.
- No claims of operating under iOS 15 on a physical iPhone 7. Xcode/XCTest pending Governor integration.
- No new IPA, release, signing, entitlements, overlay gesture, thread, or background keepalive trick.

## Real-device integration contract (future Governor window)

1. Source only real, user-approved and sanitized diagnostic snapshots from existing Link/Transport/Storage/OS observation APIs.
2. Emit a `VeilMissionSnapshot` copy at bounded cadence (or upon explicit user refresh), do not mutate subsystem state.
3. Keep existing BLE Wire v4, SQLite v10 and Keychain protection exactly as before.
4. Every capability probe must be advisory until cryptographic trust, OS permissions and actual hardware checks are satisfied.
5. Add explicit on-screen labels: "实时诊断（本地只读）" only after verified adapters, otherwise "模拟样本".

## Priority

Stabilize PR #64/#65/#66 first; then cherry-pick this zero-mutation module into a single integration branch. Ship only after iOS15 compilation, XCTest and physical gesture regression. No premature Actions.
