# Tests and integration hard gates

Static evidence completed:
- All `PATCH.diff`, `PATCH_GAME_NAV.diff`, `PATCH_A10_LIVE.diff` hunks checked against exact Build62 GitHub source, including old source contents and unified diff counts.
- `VeilFilesImportStageTests.swift` authored: stage/read/discard, oversized selection refusal, streaming coordination repeatability, and guarantee discard cannot delete arbitrary Files documents.
- Existing Build62 iOS CI run 41037180744 previously passed 763 XCTest (this does NOT test this new patch).

NOT run: new staged XCTest on Apple SDK, XcodeGen, iOS15 simulator, iPhone7 iOS15.8.3 Files provider, iCloud Drive, or two-device pairing; no IPA Action.

Must run during Governor integration:
1. Stage Files/on-device/iCloud provider documents for first-run restore, settings restore, .vltrain.json, HTML, ZIP CRC, image chat and large file integrity; confirm scoped authorization and cleanup on cancel, failure, rapid repeated imports, background/foreground and revoked source.
2. Restore a genuine OLD backup to a fresh test install with original password and check identity, chats, attachments, session keys and database integrity, preserving all rollback semantics.
3. Test input failure and file sizes: 0, just over provider limit, 1GiB integrity streaming, unicode/URL-encoded filenames and Files not-downloaded state. iPhone7 main-thread frame hitch measure for image/backup staging and move expensive copy to detached UI if needed.
4. Game hub three real views open and return with correct navigation/VoiceOver. Galgame button MUST NOT open missing WebKit vendor, always display accurate missing-resource error.
5. A10-only and independent: inject mode-specific samples, verify A10 display updates when coordinator publishes, rejects different modeSessionID, never shows A9 sample from frozen prior mode, renders explicit waiting status. Verify Owner Console.
6. Maintain current small-board tactical entry until V2 offline campaign adapter and 48×27 map asset load + regression suite are complete.
7. Manual UI/gesture tests on iPhone7 dark/light and all onboarding states; existing P0 #64–#66 remain regression candidates.

No version/release/main promotion unless full gates and Governor authorization.
