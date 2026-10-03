# VeilLink 26.11 · Build 57

Build 57 is the controlled integration release following VeilLink 26.10 Build 56.

## Highlights

- Adds three native real-time arcade experiences with deterministic model coverage: the multi-stage platformer, rhythm runner, and space-combat simulation.
- Adds four hardware-backed Live Tools: Sound Scope, Spirit Level, Screen Metronome, and Beacon, with explicit permission and unavailable-state handling.
- Hardens BLE transport with low-ATT attachment admission, direction-specific stall tracking, control-capacity reservation, and lower-copy packet handling without changing Protocol 4.
- Hardens LAN Turbo refresh and recovery so healthy links and queues survive refreshes while listener/browser failures recover independently.
- Repairs push-to-talk ordering and lifecycle behavior, restores chat assistant entry/voice quote behavior, and keeps the 40 ms PTT framing contract visible and tested.
- Adds explicit skeuomorphic performance budgets, compact-device safeguards, and regression coverage while preserving Reduce Motion and authenticated God Mode override semantics.
- Expands local-tool analysis and device stress diagnostics, including stricter readiness/acknowledgement checks and observable A9/A10 transport-health inputs.

## Compatibility and safety

- Minimum deployment target remains iOS 15 for the main app.
- Protocol 4, VLGM1 v1, SQLite Schema V8, identity/key contracts, and signing material are unchanged.
- A10 Ultra Ω remains constrained by the existing host governance boundaries; this release does not claim physical custom-chip execution.
- The published Core IPA is unsigned. It validates the iPhoneOS build and package carrier but still requires appropriate Apple signing/provisioning before normal-device installation.
- Simulator/XCTest results do not substitute for physical BLE/LAN range, RF coexistence, thermal, background scheduling, or long-duration device testing.

## Validation gates

Publication is blocked unless static preflight, XcodeGen generation, iOS Simulator build, the full XCTest inventory, unsigned iPhoneOS Release build, Core source-isolation and size/resource verification, release manifest generation, provenance generation, and SHA-256 checks all succeed.
