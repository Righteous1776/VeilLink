# Verification and iPhone 7 Acceptance

## Completed independent testing
- Linux Swift 6.2.1, SwiftPM tools 5.9: **10/10 XCTest passed**, consisting of 5 FilesIngress Foundation tests (stage/cleanup, oversized input, non-file URL, folder, never delete unrelated original) and 5 concrete sequence-forecast tests (independent game memory, concrete prediction, a lost match changing future response, unfinished penalty, rejection of illegal move).
- The tests exercised Linux Foundation without the Darwin NSFileCoordinator path. This is **NOT iOS Files-provider testing**.
- All proposed existing-file modifications generated against Build62 main exact textual anchor. Consolidated PATCH.diff rebuilt into 10 unique file sections with non-overlapping edits, original source-text verification; actual full checkout git apply and Apple SDK build still pending.

## Mandatory integration tests
- iPhone7 iOS15.8.3 + iPhone13: Onboarding Files first restore, Settings restore, valid and expired security scope, cancel/retry/password sheet delayed, external/iCloud File Provider, file copy failure, temp cleanup, no persistent access assumption; verify old chats/Keychain remain.
- Training `.vltrain.json` import/export and genuine legacy v1 format parity. Before any deletion remove truncation only after per-game separate durable store migration with backups and rollback; test large archives under storage pressure.
- HTML/ZIP inspector and file SHA read with remote Files item, empty/oversized/unavailable file; image import from Files and library separate flows; no implicit external file modification.
- A10-only enter/exit, stale sample, missing sample, epoch change, Owner Console + Settings verify A9 not shown as live when frozen; auto fallback behavior.
- GameLobby open Story/Rhythm/Lattice/GrandMap/Galgame, back-navigation, landscape/portrait, iOS15 touch overlays, zero broken inaccessible links.
- Guandu load 48×27 JSON, legal march, WEGO pair commit/reveal/resolve, fog of war no enemy leak, no tiny tactical solo shortcut, legacy multiplayer wire backwards compatibility; large map crash/thermal test.
- Training engine loss/incomplete episode replay, per-game file isolation, export/import/corruption recovery, bot safety legal-gate, deterministic UI “阵法预判”, unexpected process termination.
- Monogatari official vendor SHA verification, full R5 host, iOS15 WebKit compat, localStorage/save/restart, privacy and license before enabling launch.
- Git apply --check, XcodeGen, iOS Simulator compile, full XCTest, iPhoneOS release build, physical iPhone7. No IPA Action before governor arbitration.

## Newly authored storage tests (NOT executed yet)
`VeilPerGameLearningJournalTests.swift` checks independent per-game files/clear/stats, 1650 appended episodes without old 1600/40 pruning, per-game export/import, and invalid-file rollback. Apple iOS SDK compatibility, application integration, legacy migration and actual stress remain blocking. Existing 10 passed Linux XCTest cover only FilesIngress and in-memory sequence prediction.
