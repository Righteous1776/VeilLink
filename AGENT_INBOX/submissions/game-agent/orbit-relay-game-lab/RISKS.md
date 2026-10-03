# RISKS

## 1. Direct overlap requiring Governor arbitration

**File:** `VeilLink/UI/MiniGameViews.swift`

PR #10 (PRIMARY PRODUCT / RESTORATION CLEAN REENTRY) also changes this file. This submission does not attempt to merge, reorder, or overwrite those changes.

Required action: Integration Governor decides the final placement of the mission strip/statistics and Orbit Relay Game Lab entry after PR #10's accepted UI is known.

## 2. Behavioral adjacency with PR #10

PR #10 owns the primary Tactical V2 / skeuomorphic product-restoration surface. This proposal must not replace Tactical V2 ownership, GameLobby behavior, ArcadeGameViews, or the shared workbench design.

Orbit Relay currently uses instrument primitives already present on the current main. If the accepted PR #10 visual API changes those primitives or establishes newer controls, the Governor may adapt this proposal during integration.

## 3. Mission semantics

Some mission-progress heuristics are intentionally lightweight proxies rather than deep strategic proofs. For example, captured-piece count is used for one Xiangqi progress path and current state metrics approximate tactical objectives.

Risk: wording can imply more strategic precision than the metric actually measures.

Mitigation: preserve side-objective status, keep official game outcome independent, and revise individual metrics before product exposure if playtesting shows misleading progress.

## 4. Orbit physics/game balance

The fixed gravity coefficient, damping, fuel cost, capture radius, exclusion radius and 24-turn cap are first-pass gameplay constants.

Risk: deterministic does not automatically mean fun or balanced; certain session seeds may make relay targets easier for one side.

Mitigation: deterministic seed corpus, mirrored-start balance sampling, and distribution testing before promotion beyond Game Lab.

## 5. Bot cost

The coarse bot search evaluates many candidate simulations.

Risk: older devices may show turn latency.

Mitigation: profile on iPhone 7-class hardware; bound candidate grid/step count if required without changing rule determinism.

## 6. iOS 15 UI compatibility

Some decorative SF Symbol names may not exist on the minimum OS even though the code compiles.

Mitigation: integration-time iOS 15 visual smoke test and replacement with known-compatible symbols where necessary.

## 7. Validation status

Legacy PR #4 is evidence only. Its old branch state is not a substitute for exact-head validation against the Inbox integration batch.

Required gates: integration-time static preflight, simulator build, full XCTest, overlap review, and protected-surface review.

## 8. Rollback

Seven proposed files are additive. Their rollback is deletion if rejected. `MiniGameViews.swift` integration must be reverted surgically by the Governor because it is the only shared existing product file in this proposal.

## Overlap summary

- PR #10 direct file overlap: `VeilLink/UI/MiniGameViews.swift`
- other seven proposed paths: no direct PR #10 path overlap at preparation time
- legacy PR #4 itself: read-only evidence; must not be merged directly
- future Inbox submissions: Governor must re-check before batching
