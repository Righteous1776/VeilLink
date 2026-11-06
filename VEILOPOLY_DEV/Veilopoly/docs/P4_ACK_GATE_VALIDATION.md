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
