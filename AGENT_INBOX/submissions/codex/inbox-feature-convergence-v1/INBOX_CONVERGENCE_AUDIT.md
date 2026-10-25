# Inbox feature convergence audit — 2026-10-25

Trusted base: `501ef814a0a9bea41419fe2d9f48315371b30320`

## Current high-volume feature lines

| PR | Claimed scope | GitHub source reality | Convergence treatment |
|---|---|---|---|
| #67 / #68 | Mission Control 20 | #67 is contract-only on GitHub; #68 contains source; the owner's #67 ZIP is a separately verified candidate with an incompatible API | One conflict group; Governor selects exactly one implementation before registration |
| #69 | Feature Century 100 | Planning/acceptance catalog only | Do not register as runnable features |
| #70 | RareLab 40 | Source-inclusive engine/UI/tests | One diagnostics/experimental pack; page and search through the registry |
| #71 | Entertainment 90 | Source-inclusive E01 story candidate plus catalog | Register only actually integrated source, not all 90 design rows |
| #72 | Productivity wave | Source-inclusive variable templates, diff, merge, time-zone planner and import preflight | Lightweight productivity pack |
| #73 | Entertainment 90 R2 | Contract-only; four local candidates are in an external ZIP, not this branch | No runtime registration until exact source is ingested and verified |
| #74 | Emotion Value 1000 | Source-inclusive 1,000 runtime ritual entries with compiled Linux harness | One indexed pack; never render 1,000 cards simultaneously |
| #75 | Entertainment E091–E190 | Contract-only on GitHub; three partial engines remain in an external ZIP | No runtime registration from this PR |
| #76 | AetherLab 100 | Source-inclusive five-file candidate | One experimental pack with bounded page size |
| #78 | Entertainment 200 R4 | GitHub contains the feature gate; most candidate source remains in an external ZIP | Register the gate only after selection; do not register 200 designs as playable |
| #79 | Entertainment E191/E192 | Source-inclusive two engines and smoke tests; no navigation | Register two accepted prototypes only after Apple/iPhone validation |

## Older game lineage

- PRs #27–#34 contain overlapping V1/V2 game and asset variants.
- PR #35 is the proposed unified realtime rendering line and overlaps the same game files/assets.
- Integration should select the latest verified implementation per game and asset, not apply every historical patch in order.
- PR #26 and #10 directly touch product files and are legacy evidence/integration candidates, not safe Inbox drops.

## Primary structural problems

1. Multiple packs directly patch `VeilLink/UI/ToolCenterView.swift`, guaranteeing merge conflicts and an increasingly long grid.
2. Catalog/design counts are often presented beside source counts, making it easy to overstate what is executable.
3. Large collections use independent search/filter implementations with repeated whole-array scans.
4. Candidate features do not share one launch gate for P0 touch, data continuity, Apple build, physical-device proof, permissions, thermal state, low power or legacy-device rendering.
5. Entertainment and game proposals have generations that must be selected, not accumulated.

## Proposed convergence order

1. **P0 first:** arbitrate #64–#66 and verify iPhone 7 touch, consent input, Keychain identity and existing data.
2. **Registry foundation:** integrate `VeilFeatureRegistry.swift` and `VeilFeatureLibraryView.swift`; leave all candidate packs unregistered by default.
3. **Low-risk local packs:** register only Governor-accepted source from #72 and #74.
4. **Diagnostics:** choose one Mission Control API; then assess #70 and #76 for duplication and bounded-input safety.
5. **Entertainment:** use #78's feature gate as the policy source if accepted; ingest only exact verified sources, with #79 as two explicit candidates. Treat #73/#75 catalog rows as design until their ZIP sources are ingested.
6. **Games:** choose one source lineage per title, favoring the latest independently verified candidate; do not stack V1/V2/V3 patches.
7. **One navigation mutation:** Tool Center receives one “功能库” entry. Feature packs register descriptors and resolver routes without editing Tool Center.

## Truth boundary

This audit does not accept, merge or register another lane's proposal. It records exact observed GitHub source status and supplies a convergence mechanism for the Integration Governor.
