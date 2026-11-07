# Veilopoly unified rule set — financial AI decision guard (P4)

**Owner directive:** One Veilopoly ruleset. All decisions replay through the authoritative `GameState`, `Move`, `seededRNG` and `StateDigest`; Kimi produces the *visual* effects and animations.

## This lane's added behavior

- `FinancePolicyAdvisor.analyze(GameState, player, baseReserve, lookahead)` is a **pure Swift**, deterministic, integer-only helper. It reads already-authorized loan obligations and produces an explainable `Report` with cash reserve, amount due now / within one turn, shortfall, and the legal banking move recommended by the existing `FinancialRuleJudge`.
- The AI consumes the reported reserve for decisions in purchase, bidding, house construction and optional jail bail; it no longer ignores known near-term debt when spending cash. AI never changes interest rates or chooses unapproved financial payouts. Existing no-banking games retain the previous reserve behavior.
- A 320-seed policy corpus and edge cases check that analysis does not mutate state or consume RNG; known debt examples check the reserve and AI movement; a cross-insertion-order JSON/StateDigest test guards against the prior enum-keyed dictionary defect.
- No opaque weights or online model training were introduced. "Training" here means deterministic **scenario evaluation and adversarial replay tests** that can be expanded without undermining host/client consistency.

## Effects and Kimi boundary

- Game rules still emit the existing semantic finance `EffectKind` values. The advisor intentionally emits **no animation commands** and does not access SwiftUI/SpriteKit.
- Kimi's visual brief remains `KIMI_UNIFIED_FINANCE_EFFECTS_20261106.md`. The latest advisor `Report` fields may support a loan due warning badge; it must never display a guaranteed yield or automatically animate a transfer without a corresponding engine `Effect`.
- No new real-money wagering or gambling feature is added; all stock/fund mechanisms remain simulation-only game credits, with unapproved payouts disabled.

## Validation and strict limitations

- Dedicated local Swift 6.2.1/Linux Swift Package build and XCTest required before merge. Report exact case counts in the final checkpoint.
- These source-level tests do not certify iOS 16 simulator/device, SwiftUI, SpriteKit ACK, animation timing or the VeilLink host.
- `P5`, release, IPA, `main`, transport (`Protocol 4`, `VLGM1`) and `SQLite Schema V8` are **out of scope**.
