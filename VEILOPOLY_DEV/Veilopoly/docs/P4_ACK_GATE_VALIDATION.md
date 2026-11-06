# P4 SpriteKit animation ACK hardening — 2026-11-06

## Failure mode

The previous `GameBoardScene.play` completion closure read `currentCompletion` without checking the originating render command identity. If an old completion callback is delivered after a skip/replacement, it could acknowledge the *new* callback instead of its own, causing the `ViewCommand` queue to advance early. No engine state mutation or seed behavior is required to trigger this class of bug.

## Patch

- Added portable `RenderCommandAckGate` with monotonically advancing render token and one-shot `acknowledge(token)`.
- Every `play` creates a unique command token. Its natural callback only fires when that exact token is pending.
- `fastForward` atomically consumes the same token before canceling scene actions, applying the terminal visual frame and advancing the coordinator. Any later natural completion for that token is ignored.
- The gate lives in `VeilopolyUI`, not the pure Swift Engine, and does not modify `GameState`, `Move`, RNG, game messages or transport.
- New portable tests cover one-shot delivery, late callbacks, skip/natural callback race, canceled commands and unstarted callbacks.

## Validation (local development snapshot)

- Swift 6.2.1/Linux `swift build --jobs 2`: PASS.
- Swift 6.2.1/Linux `swift test --jobs 2 --skip 'LongSimTests|AutoplayTests'`: 42 selected tests passed, including 5 new ACK regression tests.
- This tests the **portable gate** and source/package consistency only. The `#if os(iOS)` SpriteKit code is **not compiled under Linux**. Xcode iOS 16 Simulator/device tests remain a release/integration gate.
- Kimi K1 atlas/images are unchanged; K2 visual assets remain pending, as documented separately.

## iOS acceptance checklist

1. Let dice roll (1.2s) finish naturally: phase should progress once.
2. Tap during dice roll: instant terminal dice faces, phase should progress once.
3. Tap twice rapidly during token movement: terminal tile should be correct, no skipped command and no double phase advance.
4. Skip when the last animation frame completes: no duplicate ACK, no broken action panel.
5. Restart a local game after completion and repeat, including an AI-only game.
6. Rotate between supported landscape orientations, verify capsule More and Exit hit targets; host Info.plist integration still remains P5.

## Follow-up revalidation after synchronous ACK ordering fix

- Separate scoped follow-up commit `a417901dbb66878a7455a69cc2cc101ccee8b5cc` moves `tileFx` terminal-state registration **before** the missing-tile synchronous ACK path. That prevents the old handler from overwriting `finishImmediately` of a subsequent command if a node lookup fails.
- Local source file `BoardScene.swift` Git blob SHA `f30ae67dcde367b363efc904c3e931dd296c068a`; local `RenderCommandAckGate.swift` and regression tests match the new Git tracked files.
- Swift 6.2.1/Linux `swift build --jobs 2`: PASS.
- `swift test --jobs 2 --skip 'LongSimTests|AutoplayTests'`: **42/42 PASS**, includes five new ACK gate tests.
- `swift test --jobs 2 --filter 'RenderCommandAckGateTests|K1DiceAtlasTests|LandscapeLayoutTests'`: **13/13 PASS** (overlapping with the 42, not additive).
- `swift test --jobs 2 --filter AutoplayTests`: **1/1 PASS**; 500 seeds capped at 500 moves, **0/500 natural finishes**, no illegal moves.
- `swift test --jobs 2 --filter LongSimTests`: **1/1 PASS**; 20 seeds capped at 6,000 moves, **14 completed and 6 capped**, 57,307 total moves.
- Thus **44 unique XCTest cases passed across separate runs** for this local Linux source snapshot, not a full GitHub-hosted exact-head CI run.
- `swiftc -frontend -parse` of the SwiftUI/SpriteKit source files: PASS for grammar parsing only. Linux `#if os(iOS)` excludes the iOS implementation from type checking. Actual Apple SDK build, animation race on device, frame rate and capsule interactions remain **NOT VERIFIED**.
