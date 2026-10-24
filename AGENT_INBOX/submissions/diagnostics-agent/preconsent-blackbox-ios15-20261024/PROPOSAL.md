# P0: pre-consent black box and first-sign freeze triage

## Observed device evidence
Owner's real hardware is iPhone 7 / iOS 15.8.3. Build 60 sometimes cannot complete the initial legal consent; existing regular black-box export is unreachable. On 2026-10-24 owner manually switched system to **Light** appearance, force-quit/removed app from multitasking, and launched again; event interactions unexpectedly became functional.

This is a **correlation**, not a verified root cause. Plausible failure domains include UIAppearance mutation during SwiftUI first-run layout, rendering/hit-test issues in dark VeilReleaseNeumorphicPlate/VeilAmbientBackground, old-iOS UITextField bridging / Chinese IME transient marked text, and failed legal Keychain persistence. Do not assert any single cause without evidence.

## Change
- Introduce standalone pre-consent diagnostics store before AppModel bootstrap, with bounded 128-event memory + atomic file persistence across relaunch, no Keychain/SQLite/BLE/LAN/Relay/Agent access.
- Record allow-listed event names only: launch, scene phase, theme changes, legal screen entrance, document/confirmation actions, input focus (not content), sign tap/validation/accept/persistence-failure and export.
- Capture only appearance mode, system trait, random temporary session marker, timestamp, iOS version/hardware class and app version. No free-form log message, textfield contents, identity, messages, keys or network paths.
- Use bottom safe-area inset so diagnostic entry remains available at both onboarding and the legal gate, with a standard iOS 15 share sheet and JSON file. Does not relax required legal consent or start AppModel.
- Isolated tests for bounded ring, cold-restart persistence, schema privacy and unsigned export. Full pre-sign event/hit testing requires physical iPhone 7 validation.

## Decision
First integrate and ship this **observability hotfix** under Governor validation; do not silently force light mode or claim the dark-mode signing fault is fixed. Use exported failing-vs-working startup traces for a separate causal patch once reproduced.

## Release
No version/build, signer, protocol, schema, Keychain or release changes included. Governor determines next release after exact-head CI, XCTest and core artifact gates.