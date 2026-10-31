# VeilLink 27.1 · Build 63 — Stability Convergence Candidate

**Release status:** Release candidate prepared through the Integration Governor. Publication requires completed exact-HEAD Apple CI, tested artifact identity, and Owner release authorization.

## Changes proposed for this release candidate

- Integrates the latest staged Build 62 correction line (#96, #99): file import restoration and safe staged-file ownership, A10 current-mode sample guards, separated game learning/statistics, restored game and story links.
- BLE GATT handshake watchdog/recovery candidate from Inbox #97; LAN cancellation recovery and relay failure-accounting corrections from #103.
- Game multiplayer reconnect/session state protections from Inbox #101.
- Touch/navigation density corrections from Inbox #102; avoids repeated particles on tab switching and improves actual List row hit areas.
- Gomoku default AI mode test contract corrected from Inbox #104.
- Hardened audio completion callback, texture/UI actor isolation and sendable storage clock from Inbox #107.
- Adds CI runtime evidence, structured XCTest failures, first-launch preconsent diagnostic button XCUITest, Release iPhoneOS compile check, ZIPFoundation 0.9.20 version pin from Inbox #106.
- Official Monogatari 2.8.0 R6 from controlled PR #100: 59 official resource blobs with provenance and MIT license, native read-only scheme, iOS15 fallback, byte-range tests and an additional visible GameLobby entry. The prior standalone VeilLink × Monogatari entry remains available; no existing story was deleted.

## Release and data integrity policy

- iOS remains primary; minimum deployment target iOS 15.0.
- Builds are **unsigned Core IPA**, not an App Store-signed package. Installation requires appropriate compatible signing.
- No intentional breaking changes to wire protocol, SQLite schema, identity or existing Keychain contracts in this specific integration batch.
- Duplicate or older proposals are **not automatically merged**. Especially protocol/DB migrations PR #60/#56, older touch patches #64–#66 and overlapping Monogatari implementations #98/#99/#100 require separate Governor conflict resolution; the R6 resources/host are imported once.
- Previously reported first-signing, gesture, dark/light and physical connection issues must be verified on target devices. CI passing does not certify iPhone 7 iOS 15.8.3 or iOS 26 hardware compatibility.
- Heavy local AI is deliberately excluded from standard Core, subject to its own heavy validation flow.

## Required gates

- Static release identity and source-isolation checks.
- XcodeGen, Simulator Debug build, complete XCTest + preconsent UI test.
- Unsigned iPhoneOS Release compilation and Core packaging/integrity checks.
- Owner approval for public GitHub Release and staged two-device/upgrade testing.

The release candidate is not a claim that any of the physical gates have already passed.
