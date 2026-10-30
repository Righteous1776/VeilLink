# VeilLink 27.0 · Build 62 — Inbox Convergence

VeilLink 27.0 is a major integration release built from the reviewed, source-complete Inbox proposals. Duplicate generations, catalog-only claims and already-integrated historical patches were explicitly dispositioned rather than reapplied.

## Highlights

- New V27 Feature Library with indexed search, lazy paging, conflict auditing and adaptive rendering.
- Mission Control, RareLab, Productivity Lab, Emotion Garden and AetherLab local tools.
- Branching Story Lab, Lattice Clash and the R7 native real-time rhythm renderer.
- Offline camera QR reading and pairing input validation through pinned CodeScanner 2.5.2.
- Offline HTML reading through pinned SwiftSoup 2.9.6.
- Read-only backup ZIP preflight using the existing ZIPFoundation integration.
- P0 touch reliability work for activation, PTT, tactical boards and real-time games.
- Passive raw-touch telemetry is opt-in and dynamically removed when disabled.
- Startup black-box diagnostics and corrected A9 stress assertions.
- Owner God Mode retains high-quality transient animation behavior.
- Five-in-a-row and Chinese chess now learn from local solo games with seeded opening priors, bounded on-device repertoire weights and a rolling 40-game score history.
- Portable `.vltrain.json` packages let users export training evidence for offline enhancement and re-import a validated replacement package.

## Compatibility and privacy

- Minimum iOS version remains iOS 15.
- QR and HTML tools are user-initiated. Scanned text is validated before use; HTML is parsed locally without automatic URL loading.
- Backup preflight does not extract archives or modify the database, keys or identity.
- Adaptive board-game learning stays offline in a separate, user-clearable file capped at 512 KB; older games are condensed into aggregate move weights. Imports enforce schema, checksum, size and move-range validation.
- Wire v4, SQLite v10, identity and Keychain contracts are unchanged.

## Open hardware evidence

GitHub macOS CI provides Apple SDK builds and XCTest evidence. Physical iPhone 7 consent, keyboard, camera, BLE/LAN, frame pacing and thermal checks remain device-test items and must not be inferred from simulator success.

## Artifact

The release IPA is unsigned. Installation requires user-side signing or an appropriate compatible installation environment.
