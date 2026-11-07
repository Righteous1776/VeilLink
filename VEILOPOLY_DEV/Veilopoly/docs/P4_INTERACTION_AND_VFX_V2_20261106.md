# Veilopoly P4 · 横屏 UI/UE 与轻量程序化 VFX V2

**Development scope:** `dev/veilopoly:VEILOPOLY_DEV/**` only; Kimi K2 assets stay independently owned. The game rules, RNG, wire protocol, SQLite V8, IPA and production app are not changed.

## What the playable presentation layer now does

1. **True landscape composition remains the entry requirement.** Board stays on the left, compact scrollable status/actions on the right. Upper-right WeChat-style two-cell capsule remains More / Exit, each 46×44pt; actual host orientation acceptance is still P5.
2. **Human-card reveal is a genuine pause.** A nontransparent, tappable backdrop prevents all underlying board/action touches. The scene's sound/reveal animation ACK *does not* advance the ViewCommand queue until a human presses “确认并继续”. If confirmation precedes the 0.5s reveal, the controller completes that animation once; delayed callbacks are ignored. AI players' cards show a short status message and auto-advance; AI-only games must not wait for a human.
3. **Recent event HUD.** A caption area summarises accepted Engine Effects (bank deposits/repayment, purchase, build, auction, pass GO, jail, card, victory). Error messages are visually differentiated. Event text is a fallback, never a substitute for an authoritative Effect.
4. **Tile inspector.** Side panel has 44pt Previous/Next targets, dynamic board index/name/price/owner/mortgage state. Touching the board selects a tile through SpriteKit hit-testing in the tile node's local coordinate space. A yellow selection outline differs from the mint current-player marker. The user can still inspect by buttons when physical tiles are too small.
5. **Explicit skip.** “跳过当前动画” is an accessible button; it consumes only the active render command's one-shot ACK, not the entire queue. It is hidden during card reading.
6. **Lightweight procedural effects.** Tile purchase/build/etc. pulse a native SKShapeNode ring; cash rises near the relevant pawn; turn/extra-roll/win use a visible glass-dark banner with mint outline; board cells show truncated name captions. Textures are cached per scene.
7. **Reduce Motion.** The scene applies terminal dice/token visual states and ACK immediately when the system Reduce Motion preference is enabled; no per-frame animation is required for game logic. Card reading still requires explicit confirmation for a human.

## Contract for Kimi: replace the *skin*, never the command protocol

| ViewCommand / event | Current fallback | Kimi replacement / export spec | Time/ACK |
|---|---|---|---|
| `diceRoll(DiceAnim)` | 6-frame sheet/individual die PNG | High-res dice atlas, soft shadow, final face clearly matches passed values | 1.2s; ACK once |
| `tokenMove(player,path)` | per-tile movement + bounce and step sound | Pawn turn/light/shadow frames, four token palette consistency | 150ms per tile; skip lands exactly at final index |
| `tileFx(tile,kind)` | teal pulse ring / red bankrupt ring | Frame atlas for purchase, build, mortgage, jail, bankrupt, cash; atlas or procedural shader, correct tile anchor | 0.3–1.2s; ACK once |
| `cashFloat(player,delta)` | green/red rising ¥ label next to pawn | Compact chip/coin sparkle, clear positive/negative amount | ~0.7s; remove node + ACK together |
| `cardShow(deck,text)` | audio/reveal + modal readable card | Two card backs and cards face frame, readable text inset, portrait artwork allowed inside landscape popup | reveal 0.5s; human dismiss gate; AI automatically proceeds |
| `banner(TurnInfo)` | centered translucent round plate & text | Glasslike turn/extra roll/victory badges; avoid hiding more than necessary | 0.15 in + 0.8 hold + 0.25 out; one-shot ACK |

**Critical**: Kimi assets must not call `VeilopolyEngine.apply`, mutate `GameState`, generate RNG, change player position, dispatch remote messages or directly call completion. The scene consumes `ViewCommand` and may signal **exactly one** completion to the coordinator.

## Kimi output additions for K2/K3

- Export a landscape iPhone 844×390pt and 852×393pt set, plus a landscape iPad ~1180×820pt, showing the tile inspector, More/Exit capsule, loan/asset actions, card modal, and victory banner.
- Suggested **new** optional aliases: `fxTilePulseAtlas`, `fxCashChipAtlas`, `fxTurnBanner`, `fxVictoryBadge`, `fxPawnShadowAtlas`, `uiCardFaceFrame`. Existing `diceSheetWhite`, `cardChanceAlt` and `cardChestAlt` are already staged; do not resubmit identical files.
- For each alias specify pixel size, anchor, atlas frame rects, zPosition, motion timeline, optional sound ID, SHA-256, original source URL, author/license, and an explicit `fallback=` mapping to the current procedural event. Mark `NEW/UPDATED/UNCHANGED`.
- Small-device prioritization: tiles remain identifiable via inspector even when artwork labels are small; respect safe area and 44pt touch targets; high-contrast text; no full-page vertical scroll.
- Resource budget from K2 spec: target ≤250 active SpriteKit nodes / ≤60MB live textures on a supported device; measure on Apple hardware before accepting. Existing visuals are not claimed to meet this budget.
- For `Reduce Motion`, supply static terminal states (final dice face, final pawn location, final tile ownership, readable card); no flash-only status information.

## Validation boundaries

- Portable Swift 6.2.1/Linux: new `CardRevealGateTests` **5/5** and `VeilopolyEventFeedbackTests` **3/3** passed in a local package, independently of Apple graphics SDK.
- Repo changes to SwiftUI and SpriteKit are source-level only until clean Xcode/iOS 16 compilation and Simulator/device manual tests. This turn's extended portable suite did not complete; do not recycle the former 61/61 as a new result.
- P4 acceptance matrix: iPhone landscape rotations, 40 tile Inspector taps + arrow navigation, human card dismissal (before and after reveal ACK), AI-only autoplay without card deadlock, skip/restart one-shot ACK, banner and cash node cleanup, VoiceOver / Reduce Motion / Dynamic Type and safe-area hit-testing.
