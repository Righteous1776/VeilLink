# Veilopoly · iOS 大富翁（独立 Swift Package）

> 交付：P1 纯 Swift 引擎 + P2 单机 AI 回合驱动 + P3 联机抽象 + P4 SpriteKit/SwiftUI 代码。
>
> **已写入 VeilLink 的独立 `dev/veilopoly` 分支；未合并 main、未构建 IPA。** P5 VeilLink 实际接入须另行授权与集成。所有演示数据与规则争议列于 `docs/SPEC_DECISIONS_REQUIRED.md`。

## Requirements

- Swift 5.9+
- iOS 15+ (deployment target; full Xcode/iOS 15 runtime acceptance pending)
- SpriteKit + SwiftUI (UI target is iOS-only)
- No third-party runtime dependencies
- Engine imports Foundation only; no UIKit, SwiftUI, AVFoundation, Date/UUID, ambient RNG, or floating-point comparison.

## Modules

- `VeilopolyEngine`: Codable `GameState`, 40-cell board, deterministic `seededRNG`, 18 concrete move case handlers corresponding to the specification's 15 grouped rows, cards and ledger, bankruptcy, stable `stateHash`.
- `VeilopolyAI`: 3-tier deterministic policy and bounded AI test runner, no model data or network required.
- `VeilopolyNet`: `GameTransport` interface, authoritative move packets, seq replay, mismatch handling and full-state snapshot; VeilLink adapter is intentionally not implemented.
- `VeilopolyUI`: iOS-only `VeilopolyGameView`; layered SpriteKit board, SwiftUI panels, `ViewCommand` queue and animation ack coordinator. Audio was converted from Kenney OGG to native WAV for iOS compatibility.

## Use from an iOS app

In Xcode, **File → Add Package Dependencies → Add Local…**, select this folder.
Link `VeilopolyUI`, which transitively depends on Engine, AI, Net.

```swift
import SwiftUI
import VeilopolyUI

struct ContentView: View {
    var body: some View {
        VeilopolyGameView(seed: 1729123, humanCount: 1)
    }
}
```

`humanCount` may be 0, 1, 2, 3 or 4 (in pure state); missing seats are AI. AI levels are configured in `GameFactory.make(seed:humanCount:levels:cards:)`. The default UI constructor assumes 1 local human. **Changing host transport or VeilLink chat UI is not part of this package.**

## Engine API

```swift
let g = GameFactory.make(seed: 1729123)
let ctx = VeilopolyEngine.context(g)
let move = Move(.rollDice, player: 0, seq: g.nextSeq)
switch VeilopolyEngine.apply(g, ctx, move) {
case .success((let next, let effects)):
    print(StateDigest.hash(next), effects)
case .failure(let error):
    print(error.rawValue)
}
```

Source of truth is the full project `.swift` files, not a code sketch. `Move.seq` is exactly `state.nextSeq`; rejected moves must leave the state unchanged.

## Autosave and recovery (P4 single-player)

The SwiftUI single-player view uses VeilopolyPersistence, a Foundation-only
two-slot checkpoint store in Application Support/Veilopoly/Sessions.
Every committed player/AI move saves the full deterministic GameState;
market-only ticks are batched at approximately 30 seconds, then flushed on
background and exit. On the next launch with the same solo-human-count mode,
the view restores the latest verified checkpoint rather than restarting.
Unexpected termination during animation resumes the COMMITTED game state;
unfinished visual frames are not replayed.

Two unreadable checkpoints are preserved for diagnostics until the user
explicitly requests a destructive new game.

Multiplayer host/guest checkpoint modes and MultiplayerResumeHandshake exist
as P3 contracts, but the actual VeilLink network adapter remains
P5-unimplemented. Only a trusted, authenticated host may authorize a guest
resynchronization.

For constraints and recovery validation see:
docs/PERSISTENCE_AND_MULTIPLAYER_RESUME_20261107.md

## Tests

Run on any platform with Swift 5.9+ toolchain (the iOS-only code is conditionally compiled):

```sh
swift build
swift test
swift test --enable-code-coverage --filter 'VeilopolyEngineTests|AutoplayTests'
swift test --show-codecov-path
```

Validated on Swift 6.2.1 / Linux x86_64:

- **18** named per-move test files for every `MoveKind` case.
- Deterministic replay with canonical JSON, same seed and same moves, hash checks.
- 500 AI seeds × 500 move cap: all ran without engine illegal moves; **0 finished within that bound**.
- 20 long AI seeds × 6000 move cap: **14 finished**, **6 did not finish in cap**, no engine errors.
- Network packet replay, missing-seq recovery, hash mismatch, and snapshot recovery, pure engine-level.
- **98.26% engine line coverage (732/745)** in 27-test engine+AI coverage run.
- iOS app, UI, FPS, touch, and runtime audio **not verified**: no Xcode/iOS SDK in this environment.

See `docs/VALIDATION_REPORT.md` for precise acceptance status.

## Resources

`Sources/VeilopolyUI/Resources` contains the 14 normalized Kenney PNG sprites and 12 native WAV sound clips actually referenced by the UI, not the original 1470-file source pack. The attached original planning archive contains the complete Kenney distribution if you want alternate tokens/icons.

Kenney graphics and audio are CC0 (see `docs/ASSET_LICENSES.md`). The source-spec filenames such as `pieceBlue00.png` were **not present as stated** in the upstream pack; the normalized files were extracted from `pieceBlue_single00.png` etc. Likewise source OGG has been converted to WAV for native iOS audio. The game mechanics and names are a proof-of-integration fixture pending rules-owner approval.

## Governance

`INBOX/` contains a 5-part governance handoff. No GitHub main, Protocol 4, VLGM1 v1, SQLite V8, A9/A10 gates, or VeilLink code has been changed. This development branch was explicitly created from verified `main@ccafebab147e069fbabfff579dbf323b0d54f191` on 2026-11-06. The branch is not a release or product integration.
