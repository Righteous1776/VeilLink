# Risks / overlaps

- Two source JSON files are original owner-provided training evidence and are staged in repository Inbox at owner's explicit request; project is public, so Governor must review whether game-history telemetry should be published before promotion.
- Batch contains small/non-independent histories (Gomoku 10 finished, 18 unfinished), not a validated 100%-winning pattern. Geometry alone cannot identify a unique weak point.
- `mergeReviewedPackage` intentionally only copies missing position/action stats rather than adding counts to pre-existing stats; prevents double-counting but may underweight partly overlapping archives. Duplicate record signature includes floating-point timestamp; test round trips and distinguish separate games with identical moves.
- Potential XcodeGen JSON resource inclusion needs actual Apple CI; Bundle.main lookup fails closed if missing. No manual File-picker dependency.
- Developer import changes from REPLACE to MERGE; this is intentional data preservation. Existing `importPackage` remains available as an explicit recovery path only.
- Overlap: #92/#93/#94/#95 Files pipeline, #96/#99 game learning migration, other game-training / future A10 proposals. Governor to resolve, not lane agent.
- No schema migration, version increment, main push, or IPA authority.
