# V27.0 Inbox decision ledger — 2026-10-25

GitHub inventory: 50 open pull requests. “Process all Inbox content” means every proposal receives a disposition; it does not mean applying duplicate or superseded patches in sequence.

## Integration candidates after Governor grant and Apple validation

`#21 #64 #66 #68 #70 #71 #72 #74 #76 #78 #79 #84 #86 #88 #89`

- #21: source-complete Lattice candidate.
- #64/#66: P0 diagnostic/touch proposals; patch-only and device verification required.
- #68: choose as the GitHub source-complete Mission Control implementation instead of #67.
- #70/#72/#74/#76: source-complete local feature packs.
- #71: only E01 is source-complete; the other 89 catalog rows are not runnable features.
- #78: feature gate/tests only; use as an entertainment policy base, not 200 shipped games.
- #79: only E191/E192 and smoke source are present.
- #84: preferred CodeScanner candidate; do not also integrate #81.
- #86: latest source-complete R7 rendering generation; do not stack #83.
- #88/#89: source-complete practical tool candidates, pending dependency and Apple tests.

## Arbitration or rewrite required

`#9 #35 #65`

- #9: old direct-product evidence; migrate narrowly to Inbox if still needed.
- #35: source/assets exist, but the Rainline patch has a known invalid hunk and overlaps current game paths.
- #65: contains two competing nine-file touch proposals with seven overlapping paths; choose per file before application.

## Archive, superseded or deferred

`#10 #67 #69 #73 #75 #80 #81 #83 #85`

- #10: dirty historical direct snapshot.
- #67: contract/external ZIP; superseded for GitHub integration by #68.
- #69: planning catalog, not implementation.
- #73/#75: external-package contracts/catalogs without complete GitHub source.
- #80: vendor lock/check scripts without the vendor payload.
- #81: duplicated by preferred #84.
- #83: superseded by R7 #86.
- #85: partial wrapper source depending on the missing #80 vendor engine.

## Already absorbed by main; never reapply

`#18 #19 #20 #25 #26 #27 #28 #29 #30 #32 #33 #34 #49 #50 #51 #52 #53 #54 #55 #56 #57 #58 #60`

These proposals were absorbed or evolved by Build 58–61 integration. Reapplying their historical patches risks rollback, duplicate symbols or protected-surface drift.

## Proposed order

1. Wave 0: #64, #66, then per-file arbitration of #65.
2. Wave 1: common registry/navigation, then #68/#70/#72/#74/#76.
3. Wave 2: #78 → #79 → #86, selecting R7 paths only.
4. Wave 3: #21, #71 E01 only, #84, #88 and #89.
5. Wave 4: dependency/license review, iOS simulator/full XCTest, then physical iPhone 7 consent/input/data/BLE/LAN/render/thermal validation.

This ledger is a read-only triage result. It does not accept or merge another lane's work.
