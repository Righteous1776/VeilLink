# Veilopoly iOS 15 minimum — compatibility gate

Task `VL-VEILOPOLY-IOS15-UNIFIED-20261107`.

- SwiftPM package target minimum changed from iOS 16 to **iOS 15**; macOS 13 target unchanged.
- Removed the unnecessary `.persistentSystemOverlays(.hidden)` SwiftUI call, avoiding a newer-OS-only presentation requirement.
- Replaced unconditional iOS 16 `UIWindowScene.requestGeometryUpdate` and `UIViewController.setNeedsUpdateOfSupportedInterfaceOrientations` with `#available(iOS 16, *)` gates. On iOS 15 only public UIKit `UIViewController.attemptRotationToDeviceOrientation()` is used. The host must allow landscape via Info.plist; otherwise the existing portrait rotate-device view is shown.
- Removed `.scrollIndicators(.hidden)`; scrollbar visibility now uses system behavior on iOS 15.
- No private rotation selectors, Info.plist host edits, iOS deployment changes to other games or main.
- iPhone 7 iOS 15.8.3 is a **target to validate**, not verified as actually running. The source still needs Xcode iOS 15 SDK availability compile, full XCTest, memory/touch performance on older devices.
- iOS 15 is the requested *project-wide policy goal*; within this restricted game branch, only Veilopoly was changed. Other games need their own audited platform/availability migrations.

Reference: Apple iOS 16 release notes introduce UIWindowScene geometry preferences, so the new gate is necessary.
