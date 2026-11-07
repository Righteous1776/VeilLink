# VLP-CONTINUATION-002 — Read-only achievement journal

Baseline: `dev/veilopoly@09ac83b6033f5205ff471dd494e8819f8a16855e`; main `2c5b5161027edff097b27fe3323d30f6ca3e430e`.

## Scope and implementation

- New `VeilopolyEngine/VeilopolyAchievements.swift`: 16 original in-game milestone definitions, per-seat historical move counts and **CURRENT** property/district/hotel conditions.
- `VeilopolyUI/VeilopolyAchievementJournal.swift` and `AssetBrowser.swift`: accessible read-only in the phase-independent asset browser under “成就档案”, with counts, progress and explanatory copy.
- New `AchievementJournalTests.swift`: initial state, per-seat/positive-bid history, changing portfolio and winner, invalid seat, read-only state digest.
- No new GameState or save fields, no cards/money/rewards, no mutations, no rules, no RNG, no signed assets or gameplay wire messages.

## Verification

- Local Swift 6.2.1 isolated compilation + smoke test of the pure achievement projection **PASS** against a deliberately minimal interface stub (16 definitions, seat isolation, positive bids, current districts).
- Exact full SwiftPM package tests **NOT_RUN** in this action: full repository is available only via connector, not downloaded in this executor.
- Apple SDK / SwiftUI type-check / iOS XCTest / screenshots / real device **NOT_RUN**. Do not interpret isolated stub compile as whole-package success.
- API reviewed against `Models.swift` (`GameState`, `MoveKind`, `ColorGroup`, `Tile`). Historical actions are defined by committed `moveLog`, which is assumed to come from the canonical reducer; not a cryptographic proof of remote validity.
- No main, workflow, transport, encryption, schema, version or IPA changes.

Next: validate branch using available full SwiftPM runner, then Apple SDK/device; improve phase/debt indices and oversized snapshot resilience, keeping gameplay progress gated on peer status.
