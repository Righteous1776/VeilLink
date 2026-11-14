# VeilLink 29.2 · Build 68 — INBOX consolidation candidate

## Integrated functional changes (from Governor Waves 1–3)

- Chat keyboard safe-area layout and end-of-thread anchoring, plus local SQLite insertion sequence for chat bubble ordering independent of a peer's clock drift (PR #230).
- Apple Files unified content-based import and staging safety checks (PR #227).
- Aggressive photo/screenshot compression using actual smallest encoded candidate without corrupting file contents (PR #224).
- Veilopoly/game-session quiet-time recovery and BLE GATT/queue backpressure improvements without resetting a healthy encrypted chat session (PR #228).
- Removal of unnecessary global particle animation, preserving relevant local effects (PR #229).
- Game lobby `LazyVStack`, removal of zero-distance decorative drag handlers, and reduced unrelated motion work to preserve vertical scrolling (PR #235).
- FORGE industrial orange/graphite theme with theme-scoped RF/CPU instrumentation and accessibility/motion policy (PR #233), reworked to preserve Wave 1 keyboard stability.
- Flight Recorder R5: 512 MiB configurable retention budget, bounded pre-consent events, rotation/integrity and structural bubble-order diagnostics; module telemetry and **explicitly opt-in** pass-through touch capture with secure-input/keyboard redaction (PR #222).

## Important exclusions — DO NOT represent as shipped

- VeilScreen R1/R2.1 ReplayKit Broadcast Upload Extension is still an Inbox candidate; **system-level BLE screen sharing is not available in this IPA**. End-to-end secure media transport, signed extension/app groups, local broadcast consent and dual-device background checks remain unfinished.
- ECLIPSE R17.2 mechanical cockpit has an incompatible R16/R17 hybrid baseline and is **not** in this build. ECLIPSE R14 from Build 67 remains.
- Any other historical Inbox proposal not explicitly listed above remains subject to separate integration and test review.
- Experimental native language models / GGUF are not bundled; model-free VeilTalk Lite remains.

## Release gate and acceptance

Release only from this exact Git commit after full macOS SwiftPM tests, iOS simulator build, XCTest/UI smoke, unsigned device Release build, IPA integrity, payload size and content/asset provenance verification complete successfully.

Dual-phone BLE/Veilopoly recovery, iOS15 ReplayKit compatibility, actual RF throughput, keyboard/scroller gestures, 512 MiB recorder retention and touch privacy must still be verified on physical devices. Simulator/CI success is not a real-device claim. Existing user data must be backed up and preserved. The IPA is **unsigned**, requires user-owned signing for installation and must not be confused with a signed production build.
