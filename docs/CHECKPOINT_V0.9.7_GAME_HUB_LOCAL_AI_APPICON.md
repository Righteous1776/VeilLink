# VeilLink V0.9.7 (41) release checkpoint

Baseline: GitHub `main` at `77bc0a40fa2ee3fff9cab6552c553aa981e83a7c`.

## Included lineage

- V0.9.4 deep telemetry and privacy-safe diagnostic export.
- V0.9.5 bounded device burn-in controls.
- V0.9.6 real local-AI pipeline, embedded VFLY1 Core/Lite graphs, learned readouts, legal-action game ranking and AI Control Center.
- V0.9.7 standalone Game Hub with offline Gomoku, Xiangqi and Ludo opponents.
- Complete embedded AppIcon catalog generated from the creator-provided square source.

## Preserved boundaries

- Protocol 4, VLGM1 v1 and SQLite Schema V8 are unchanged.
- Local AI cannot invent or directly inject a game action; the existing engine enumerates and revalidates every candidate.
- 三国兵棋 AI remains disabled until a dedicated tactical policy is trained and validated.
- Conversation plaintext, attachments, keys, pairing codes and passwords are excluded from automatic Agent context.
- Experimental Core mode does not survive a cold launch and is unavailable on the iPhone 7/A10 profile.
- The hidden App easter egg remains present; its trigger and contents are not documented.

## Embedded assets

- `VeilFlyCore.vfly`: SHA-256 `cc8b71d824ecb7f20c821412b316262ecb4dd1faee148077c94825b5889d60de`.
- `VeilFlyLite.vfly`: SHA-256 `25b4947ec6c2a33502879d92269299120b708e86110157a538f792e327b7abee`.
- AppIcon source artwork: SHA-256 `d1bf3a57384200a0e8cb447bb9fc22ef317294058f484bb75c2b09fc6bc097a0`.
- App Store 1024 px icon: SHA-256 `424f6241230f82e4fbc6516303500083bcfa479282931ec317e07d8c26854f95`.

## Release gates

The source must pass XcodeGen generation, iOS Simulator compilation, complete XCTest, Release `iphoneos` compilation, bundled VFLY/Qwen verification and unsigned IPA packaging on GitHub's macOS runner. Real-device BLE, latency and thermal behavior remain device-validation gates and are not inferred from CI.
