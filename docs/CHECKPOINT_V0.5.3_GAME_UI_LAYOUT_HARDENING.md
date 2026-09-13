# V0.5.3 — Game UI Layout Hardening

## Scope

Targeted layout correction only. No game-rule, BLE protocol, crypto, payload-format, or database-schema change.

## Fixed

- Derive the tactical battlefield aspect ratio from the exact cached 7×9 hex footprint instead of a hand-tuned constant.
- Prevent occupied objective labels from spilling into the following hex row; use a compact objective notch while a counter occupies the cell.
- Reduce the fixed attack marker so it fits the minimum iPhone SE1 / iPhone 7 tactical hex height.
- Explicitly stretch the Xiangqi `楚河 / 汉界` label row across the river instead of relying on an unconstrained `HStack` inside a `ZStack`.
- Bound key status/header strings with one-line scaling to avoid compact-width compression cascades.

## LocalLab layout audit

The CI simulator verifies that every cached tactical hex footprint remains within normalized board bounds, that the derived board aspect ratio matches the geometry, and that the attack marker fits a 300 pt compact battlefield width. Swift parsing and existing BLE/core harnesses remain mandatory.

## Remaining visual gate

Actual SwiftUI rendering still requires Work/macOS/Xcode screenshots on SE1, iPhone 7, SE2 and iPhone 13 Pro in portrait/landscape. Static LocalLab checks reduce deterministic layout errors but do not replace Apple layout-engine rendering.
