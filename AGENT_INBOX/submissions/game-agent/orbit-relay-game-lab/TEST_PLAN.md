# TEST_PLAN

No product CI or workflow was dispatched by this Inbox agent. The following tests are required only after the Integration Governor applies an accepted batch to an integration branch.

## Patch/application checks

1. Apply `PATCH.diff` against exact base `c81f266e0032a1d0868cb25ddc26b690ddea4e43`.
2. Confirm only the eight declared product/test files change.
3. Confirm no version/build/release/workflow/protocol/schema/identity/A9/A10 drift.
4. Re-run changed-file overlap detection against all submissions selected for the same batch.

## Focused mission tests

- same game + same session ID selects the same mission;
- every current `MiniGameKind` produces a non-empty mission;
- mission progress stays within `0...1`;
- evaluator does not mutate underlying game state;
- Artillery progress observes a resolved shot;
- Tactical supply mission evaluation remains read-only;
- finished-session mission display does not alter official outcome.

## Focused Orbit Relay tests

- relay point generation is deterministic for session ID + index;
- identical starting state + move + session ID produces identical resulting state and sampled path;
- invalid angle/power/actor moves are rejected without mutation;
- turn ownership switches only after a legal move;
- fuel never drops below zero;
- stability/winner/draw conditions are bounded;
- bot always returns a move accepted by the same rule engine, or no move only when appropriate;
- bot search is deterministic for the same state/session;
- relay capture and boundary/well penalties are reproducible.

## UI smoke tests

- Game Lab entry presents and dismisses normally;
- Orbit Relay arena renders in portrait on compact iPhone layouts;
- controls remain usable with Dynamic Type;
- Reduce Motion path does not require animation;
- mission strip handles active and finished sessions;
- no missing/blank critical SF Symbols on iOS 15 baseline; replace unavailable decorative symbols if needed;
- VoiceOver labels exist for the arena and primary controls.

## Regression tests

- existing Gomoku/Xiangqi/Ludo/Tactical/Artillery/Light Trail/Magnetic Hockey legal move and winner tests;
- Tactical V2 primary-entry regression guard after PR #10 integration;
- existing MiniGame hub statistics and navigation;
- full XCTest inventory;
- standard static preflight;
- XcodeGen/project generation;
- iOS Simulator build using the repository deployment target.

## Performance checks

- measure worst-case Orbit Relay bot choice time on an iPhone 7-class performance budget;
- verify fixed-step simulation does not cause UI-thread stalls during repeated turns;
- verify no runtime asset/model memory growth.
