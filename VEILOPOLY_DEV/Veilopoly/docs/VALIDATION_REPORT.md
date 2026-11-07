# Veilopoly · Validation Report / 2026-11-06

## Staged status

| Phase | Implemented | Executed checks | Status |
|---|---|---|---|
| P1 Engine | Data models, RNG, reducer, 18 concrete case variants, 32 configurable sample cards, liquidations, bankruptcy | Swift 6.2.1 Linux build; 18 individual move tests; 180-step exact replay; hash compare; economy tests | **Verified on portable engine**, subject to game-rule ambiguity |
| P2 Local | AI 3 levels, 4-player simulation, buy/auction/trade state machines, local UI coordinator | 500 seed games with 500-move bound: no illegal moves; long 20 seeds × 6000 moves: 14 finish, 6 time out | **Partially verified. 500 complete games NOT certified** |
| P3 Network abstraction | GameTransport protocol, host seq, replay, packet hash, missing-seq resend, snapshots, placeholder P5 adapter | Gap, mismatch and resync tests on Linux | **Verified as engine-level logic only; no actual transport/4-device crash test** |
| P4 Rendering | SpriteKit L0–L7, effects translator, 1.2s dice animation, 150ms step, fast-forward ACK, SwiftUI panels, 14 PNG + 12 WAV | Swift source syntax parse and non-iOS fallback `swift build` | **Unverified on iOS: requires macOS Xcode simulator and physical device** |

## Automated results

- `swift test` (before final UI-only changes): 31 automated checks passed, zero XCTest failures.
- `swift test --enable-code-coverage --filter 'VeilopolyEngineTests|AutoplayTests'`: 27 checks passed, zero failures; line coverage 732/745 = **98.26%** for Sources/VeilopolyEngine.
- 500 AI seeds are **bounded smoke tests**, not full 500-game completions. Average real-time game duration **not measured**.
- 20 exploratory games cap 6000 moves: 14 finished, 6 capped; does not prove an upper bound on game length.
- Random engine RNG uses only `seededRNG(seed:counter:)`; no system RNG calls.
- Hash algorithm: UTF-8 sorted-key JSON and unsigned FNV-1a 64-bit, includes persistent move log; invariant checked for same Swift runtime and encoding. Cross-OS iOS/Linux canonicalization remains to be verified by golden vectors.

## Known gaps before production

1. Confirm/replace provisional 22-street rent/price names and exact 32-card content.
2. Decide non-standard edge rules in `SPEC_DECISIONS_REQUIRED.md`.
3. Test entire iOS target using Xcode / iOS 16 simulator, add SpriteKit timing and touch tests.
4. Add a full 500 finished game acceptance harness (some simulated games remain unresolved at 6000 moves).
5. Run four-device process-kill resync test after P5 transport integration.
6. Validate `iPhone 8` CPU <30%, board construction <300ms, 60FPS and resource budget on real hardware; all unmeasured.
7. Chat entry and VeilLink networking are P5 deliberately excluded.
