# Risk register and conflicts

- Shared `VeilLink/UI/ToolCenterView.swift` overlap with draft PR #67/#68/#70/#72/#76; Governor must merge one localized QR button without overwriting other proposed UI additions.
- Remote pairing still depends on **Internet Relay**; adding a camera scanner cannot create a purely BLE offline remote handshake. Do not mislead.
- PIN/QR bearer codes and URLs: do not auto-open links, store camera captures, print QR text to logs, send over network, or relax QR expiry.
- CodeScanner requests camera permission. Respect denial; no background capture. Existing NSCameraUsageDescription was agent-only and needs updating.
- Adding CodeScanner increases app size/build surface, but package has zero SPM dependencies; pin to 2.5.2 and review upstream MIT LICENSE/Copyright.
- CodeScanner can use UIKit/AVFoundation camera views; test iPhone7 focus, lifecycle and SwiftUI `sheet` interactions under light/dark and known root gesture P0. Avoid further UI overlays.
- Source proposed under FILES may compile but is **not** yet built with Apple iOS SDK; Linux Swift checks only for Foundation policy.
- QR preflight validation is not authentication: the existing pairing coordinator must still validate cryptographic payload, age and SAS confirmation.
- Security boundary: No microphone, photo-album, BLE protocol, encrypted SQLite, Keychain, A9/A10 or signing mutation proposed.
