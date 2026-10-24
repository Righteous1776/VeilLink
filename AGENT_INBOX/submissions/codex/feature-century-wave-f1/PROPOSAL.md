# Feature Century Wave F1 — Productivity Lab

## Outcome

Stage a compact, local-only productivity surface that delivers five callable user workflows from four Feature Century contracts:

1. **FC-053 variable message templates** — extracts unique `{{variables}}`, refuses malformed/missing values, and produces a preview without sending.
2. **FC-057 text diff** — deterministic line-level LCS edit script with explicit additions/removals.
3. **FC-057 conservative three-way merge** — auto-resolves only identical or one-sided edits; bilateral edits receive visible conflict markers.
4. **FC-058 cross-time-zone planning** — ranks half-hour slots using real IANA time zones and DST-aware Foundation calendars.
5. **FC-060 universal import preflight** — checks traversal-like names, Unicode/case-normalized duplicates, negative/zero sizes, allowlisted extensions, item count, total size and integer overflow without importing anything.

## Acceleration design

- One shared engine, one navigable lab, one focused XCTest file.
- No persistence or migration dependency.
- No network/Bluetooth/background work and no new entitlement.
- No automatic chat send, file import or destructive action.
- Hard computation budgets: 64 KB text, 400 lines per diff side, 24 participants, 7-day planning horizon, 500 imports and 2 GiB default total.
- Uses current VeilLink theme components and standard SwiftUI controls, retaining iOS 15 compatibility intent.

## Integration sequence

1. Resolve P0 touch/data continuity PRs #64–#66 first.
2. Governor reconciles the single `ToolCenterView.swift` insertion with PR #65, Mission Control #67/#68, and RareLab #70.
3. Apply only this patch on a dedicated integration branch.
4. Run XcodeGen, iOS 15 build, full XCTest, VoiceOver/dynamic-type checks, light/dark mode, and physical iPhone 7 touch checks.
5. Promotion/release remains owner + Integration Governor authority.

## Truth boundary

This is staged candidate source, not an integrated app update. It never claims to read live chat, calendars or files. Time-zone rows and import manifests are entered by the user.

