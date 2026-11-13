# Portrait dashboard validation and explicit missing gates

SOURCE CHECKS:
- Patch must apply to `dev/veilopoly@afa560718c2f8ac1bde0b73dcdc44a8451782c93`. Add PortraitWorkspace.swift and PortraitLayoutTests.swift. Confirm only five VeilopolyUI and one VeilopolyUITests path changed.
- Swift compile with iOS15 SDK and Run SwiftPM/host XCTests (not run by this submission); verify `@AppStorage` and imported symbols. Run PortraitLayoutTests and existing LandscapeLayoutTests.
- Verify game info, SaveStore, ACK, Engine, AI and Net compile and behave unchanged; no duplicate GameSessionModel or scene rebuild on panel collapse.

HARDWARE TEST MATRIX (must stay NOT_RUN until tested):
- iPhone7 375x667/iOS15.8.3 and iPhoneSE2/iOS15.6.1 portrait first launch: board occupies <=half viewport with readable 40 cells; lower panel full width, no top-right obstructing capsule. Test large text, VoiceOver, safe areas and keyboard-free numpad.
- Collapse by explicit button and title-handle downward drag only; dashboard scroll must not drag panel. At 0.55s long-press die, same panel content/drafts/scroll state return; short tap must NOT trigger roll or trading.
- Cards: all 6 selectable, preference persists across relaunch; bank rate/market price match authoritative GameState and own seat, not active AI. During AI turn and another human turn, live read-only widgets and existing asset browser work. They cannot place orders (display clear legal-phase restrictions).
- Rotate to landscape: no explicit request from package, 44pt one-button More/Exit remains available and no board crop; return portrait. Host orientation is contingent on Info.plist. Confirm game saves and token layout unchanged.
- Multiplayer same room, guest seat shows guest cash and bank, not host/turn actor; no secure session/encrypted control modifications.
- Test screenshot sizes ~375x667, ~390x844, ~820x1180; dynamic type and Reduce Motion (no forced animation).

SEPARATE FEATURE GATE:
- User requested truly independent out-of-turn financial actions. Document and test as separate Engine + host-authoritative Net assignment only after explicit Governor grant; reject any UI-only claim of this behavior.
