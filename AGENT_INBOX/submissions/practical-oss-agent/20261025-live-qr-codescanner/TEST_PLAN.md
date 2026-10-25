# Targeted integration gates

## Completed locally
- Linux Swift 6.2.1 stand-alone SwiftPM engine/XCTest: **4 passing, 0 failures**, tests cover correct synthetic base64url shape, wrong prefix/version, non-base64url/Unicode/whitespace rejection, 4096-byte bound.
- GitHub tool read exact base main `501ef814a0a9bea41419fe2d9f48315371b30320`, verified every original line and old/new hunk count across four diffed paths: `project.yml`, `VeilLink/UI/RemotePairingView.swift`, `VeilLink/UI/ToolCenterView.swift`, `VeilLink/Resources/Info.plist`. 8 hunks total.
- CodeScanner 2.5.2 `Package.swift` and `CodeScannerView` public initializer names inspected at tagged source; package Swift 5.9 and iOS 13. No copied vendor binaries.
- **Not** run: full `git apply --check` on product checkout, XcodeGen resolve, Apple UIKit/SwiftUI typecheck, full XCTest or iPhone7 real camera.

## Governor integration tests (must pass before release)
1. Rebase manually onto current main/approved integration branch; reconcile project.yml/Info.plist/ToolCenterView shared changes from any competing agent.
2. XcodeGen package resolve exact `2.5.2`, assert `CodeScanner` product links to app and not `VeilBackgroundWidget`. Verify MIT acknowledgements ship with app.
3. iOS 15.8.3 iPhone7 and iPhone13 Pro cold camera authorization, permission denied, settings re-enabled, no usable camera, application background/foreground and dismiss/reopen.
4. Remote QR valid+fresh => original Coordinator; expired/tampered/malformed => original codec rejects; no silently trusted peer and no stripping validation. Test live capture vs existing PhotosUI import parity.
5. Remote scanner requires Relay configuration and network to complete pairing; when absent show existing error instead of claiming offline Bluetooth pairing.
6. Generic reader with benign text, URL, multiline, 4KiB and oversize: no auto open, no network, no app DB write, no raw QR logging; clipboard changes only on explicit tap.
7. VoiceOver, large Dynamic Type, light/dark mode, sheet dismissal, toolbar "取消", re-entry, camera orientation, focus on real iPhone7. Check existing P0 global hit testing and sliders.
8. Compare battery/memory and repeated scanner opens (capture session release), camera resource races with Voice/Agent video screens.
9. Run full iOS XCTest suite; verify preconsent blackbox and Keychain failure paths unchanged.

Hard gate: no IPA Actions/release/merge until P0 #64/#65/#66 resolved and integration Governor selects this patch.
