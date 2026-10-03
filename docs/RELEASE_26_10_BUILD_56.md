# VeilLink 26.10 · Build 56

Build 56 is the cumulative feature and maintenance release based on the complete
26.9 Build 55 recovery line.

## Highlights

- Tactical Solo V1 makes 三国兵棋 playable offline against a deterministic local bot,
  with an in-app beginner tutorial, rules reference, daily scenario, replay, and
  legal-move-only AI boundary.
- 弧光炮战、光轨突围 and 磁轨冰球 add original 2D play with offline bots and nearby
  encrypted multiplayer reconstruction from the existing game event stream.
- Tool Center now contains 13 local utilities for passwords, hashes, QR, LAN/BLE
  status, JSON, Base64, URL encoding, timestamps, UUIDs, text cleanup, color values,
  random choice/dice, and Morse, alongside encrypted push-to-talk.
- LAN Turbo, compact-screen layout, Dynamic Type/accessibility behavior, render
  caching, and adaptive visual effects receive a cumulative hardening pass.
- Automatic mode retains efficient motion on compact devices and respects Reduce
  Motion. Authenticated God mode may explicitly force the high-quality transient
  effect path; persistent decorative animation remains separately controlled.
- A10 Ultra Ω remains an independent, fail-closed governance path with immediate A9
  fallback. A10 Ultra M5 stays shadow-only with `production_cutover: DENY`.

## Compatibility and safety

- Minimum deployment target remains iOS 15.
- Protocol 4, VLGM1 v1, and SQLite Schema V8 are unchanged.
- The IPA published by GitHub Actions is unsigned. It proves compilation and package
  construction for `iphoneos`, but it is not directly installable on a normal iPhone
  without Apple signing and a matching provisioning profile.
- Simulator and deterministic tests do not prove physical BLE/LAN range, throughput,
  background scheduling, thermal behavior, or cross-device floating-point identity.
- VLGM1 v1 has no causal-parent or rules-version field. Build 56 preserves that wire
  compatibility; a future protocol revision should add explicit causal/version data.

## Validation gates

The release is blocked unless the standard static preflight, simulator build, XCTest
suite, unsigned `iphoneos` Release build, source-isolation checks, recovery-lineage
checks, Core IPA size/resource verification, manifest generation, and SHA-256
provenance generation all succeed.
