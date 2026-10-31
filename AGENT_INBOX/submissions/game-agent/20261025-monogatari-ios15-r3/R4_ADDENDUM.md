# Monogatari R4 Playability Compatibility Addendum — 2026-10-25

This is an update to **the same Game Agent R3 Inbox lane**. It is not a functional merged game, not an IPA, and must not be self-merged.

## Complete owner-delivered candidate
- Artifact: `VeilLink_Monogatari_Playability_R4_20261025.zip` (in the current ChatGPT conversation).
- ZIP bytes: **5,674,020**; SHA-256: `8a0b419d5184edbb41c99ab0cfc4935b14125ced586e2c200c5bd747d18dfa72`.
- 111 archive entries; original official ZIP SHA-256 `16d221485888b0193312e9989ecafa57cb1913978bf2f09ba554552ba3885806`; entire upstream `engine/` subtree remains unmodified.
- Full R4 SwiftUI host, scripts, CSS, optional file loading mode, test suites and tools are in that **user-facing ZIP**, not all in this PR.

## Actual new code staged in GitHub
- `FILES/Tools/VNPort/overlays/js/veillink-ios15-compat.js`: executable additive Safari/WebKit origin compatibility polyfill for missing `crypto.randomUUID` and `Object.hasOwn`, never using Math.random.
- `R4_PATCH.diff`: proposed add-only source patch for this shim. Governor may accept after review.

## Other improvements only in the full owner ZIP
1. Native WKWebView manual `loadFileURL(_:allowingReadAccessTo:)` fallback when custom-scheme navigation/init fails; file and custom scheme may have separate save namespaces.
2. 20-second startup deadline, explicit user reload, stale coordinator event invalidation.
3. JS native notification bridge is loaded before JS main init; compatibility shim before official engine.
4. Small-screen touch targets, keyboard focus and reduce-motion style overlay.
5. XcodeGen nested `type: folder` reference check and conservative optional repair for **generated .pbxproj**.
6. Reproducible genuine ZIP reimport (60 game files), negative integrity tests and corrected movable integration tests.

## Local validation achieved
- True official release ZIP SHA256 PASS; 56 upstream files present; 12 engine binaries byte-for-byte PASS.
- All 60 regenerated game files match R4 candidate; 19 nodes/3 choices/4 endings story graph.
- 15 Swift byte-range tests, 5 PBX path fixtures, JS bridge/launch-order/UUID shims, mock integration dry run/apply/reapply rejection PASS.
- Swift parser only; NOT Apple SDK SwiftUI typecheck.
- Browser smoke attempt blocked by execution environment's administrator policy. NO iPhone 7 device runtime, offline save/restore, touch or audio test has run.

## Hard acceptance gates
Prioritize #64/#65/#66 iOS15 startup/gesture/data P0. On a separate Governor integration branch ingest **verified complete owner ZIP**, inspect XcodeGen compiled .app folder tree, run macOS iOS15/XCTest and physical iPhone7 dark/light/gesture/save/relaunch/branch/media validation. DO NOT merge main, change signing/version, or dispatch IPA Action until gates pass and owner authorizes release.

**Status: SOURCE CANDIDATE VERIFIED; FULL GAME PLAYABILITY UNCONFIRMED.**
