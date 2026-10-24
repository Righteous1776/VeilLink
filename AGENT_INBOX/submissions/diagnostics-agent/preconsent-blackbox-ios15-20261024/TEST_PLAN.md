# Acceptance tests

1. Static: git apply --check against bfcf81cf90819e53f6d57ff152f4fe6eb86ad5b4; no source edits in Inbox branch.
2. XcodeGen and iOS 15 simulator build; run full XCTest, including PreConsentBlackBoxTests.
3. Fresh legal state: verify bottom inset **导出临时黑匣子** appears on first-activation pages and legal gate before signature, not after signature.
4. Tap export on first launch without signing. iOS 15 UIActivityViewController presents JSON; File Save or AirDrop works. Verify JSON has launch/appearance and no acknowledgment, PIN, Keychain, contacts or plaintext.
5. Tap all three confirm rows and edit acknowledgment with Chinese IME; compare signTapped/signIncomplete/signSaved/signStorageFailed. No plaintext stored. Trigger failure with storage/full disk if test bench available.
6. Dark system appearance + cold launch; record first failed event; switch to Light + force quit + cold launch; export both sessions and compare their event timelines.
7. iPhone 7 physical device: tap reachability, keyboard, scrolling, no unresponsive control caused by bottom safe-area rail; system Share Sheet presentation.
8. Real long relaunch: ensure at most 128 events persisted; restore after force quit; no AppModel or SQLite opened before consent.
9. Inability to access Application Support: app still displays legal UI; export fails politely; never blocks signing.
10. Governor: inspect exact head, check current feature migration and run full unsigned Core build / release provenance; no release before tests pass.

Criteria: pre-consent export from both entrances, strict absence of sensitive contents, persistence across cold relaunch, no regression to consent gating, no illicit product edits.
