# Third-party chess engine intake audit

Date: 2026-10-30

## Owner direction

External GitHub source may be imported when its licence, provenance, iOS build
path and redistribution terms are auditable. This does not relax the Inbox-only
or release gates.

## Research outcome

- `JiachenRen/GomokuZero` describes threat-space search, alpha-beta, Zobrist
  hashing, principal-variation search and MCTS, but GitHub currently reports no
  licence. It is useful as an algorithm reading list, not vendorable source.
- `gooooloo/XiangqiNotebook` and the common Pikafish-based Xiangqi projects
  found in GitHub search currently do not present a clean permissive source
  intake for this iOS target. Pikafish/Stockfish-derived engines need a separate
  GPL compatibility and packaging review before any binary or source intake.
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
