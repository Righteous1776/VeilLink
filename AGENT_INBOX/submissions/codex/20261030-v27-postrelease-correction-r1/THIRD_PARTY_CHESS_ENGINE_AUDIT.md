# Third-party chess engine intake audit

Date: 2026-10-30

## Owner direction

External GitHub source may be imported when its licence, provenance, iOS build
path and redistribution terms are auditable. This does not relax the Inbox-only
or release gates.

## Research outcome

- `JiachenRen/GomokuZero` is MIT at `9ff66c28701417d6786b6e493b1cef08a0887f0e`.
  Its Swift threat-search, Zobrist and iterative-search structure is a viable
  source-level intake candidate, subject to attribution and an iOS 15 port
  review. It is not yet vendored in this submission.
- `maksimKorzh/wukong-xiangqi` is MIT at
  `9ef8db735e78ec640a64d50240698087b44c5294`, but its engine is JavaScript and
  cannot be silently embedded as a native iOS binary dependency.
- `gooooloo/XiangqiNotebook` is MIT at
  `61ff49bcac427080dbf423c648fc08554c39a941`, but its external engine/dependency
  graph still needs a file-level audit before source intake.
- Pikafish/Stockfish-derived engines require a separate GPL compatibility and
  packaging review before any binary or source intake.
- No binary engine, weights, archive or external dependency is staged by this
  candidate.

## Current safe improvement

The candidate keeps the existing native Swift rule engines, adds selectable
search budgets, a deeper Gomoku continuation pass at higher tiers, and uses the
already-auditable local learning records at every tier. This is immediately
testable on iOS without a licence or packaging surprise.

## Future intake gate

Before importing a permissively licensed engine, record its immutable commit,
licence text/SPDX identifier, authorship attribution, source URL, dependency
graph, iOS 15 build result, deterministic-rule regression, performance budget
and removal plan. GPL engines require an owner-approved licensing decision and
must not be quietly linked into a proprietary IPA.
