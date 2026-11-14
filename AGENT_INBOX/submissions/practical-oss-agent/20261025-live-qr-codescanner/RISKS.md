# Risks, open dependencies and conflict record

- **High-priority incidents are unresolved:** PR #64 global gesture and Keychain diagnostics, PR #65 local gestures, PR #66 UIWindow recorder. Direct camera scanning introduces a full-screen UIKit capture view; iPhone7 iOS15 touch conflicts must be tested in both system appearances and after cancellation.
- **Shared files**: `project.yml` and `Info.plist` require protected-surface review; `VeilLink/UI/ToolCenterView.swift` already has additive proposals in #67/#68/#70/#76/#72 and other lanes. Manually reconcile a single ToolCenter candidate during Governor window; no rebase/merge of other agents by this lane.
- **External dependency**: The tagged CodeScanner v2.5.2 Swift tools 5.9 and iOS13 minimum were verified from upstream manifest. SwiftUI/AVFoundation build and capture behavior on real iPhone7 NOT yet verified.
- **Privacy**: Raw captured QR may be a bearer capability. The camera result must never be logged or auto-shared, nor displayed in plain text on remote-pair screen. Generic reader displays text by user choice only; phone clipboard risks are documented and copy is manual.
- **Security**: The synthetic input-shape gate only prevents accidental malformed/crowded QR payload; it is **not** an identity/authentication/expiry check. Existing `VeilRemotePairQRCodeCodec.decode` and Coordinator must stay authoritative.
- **Availability**: Camera scanning can fail due to permission, focus or capture-session preemption; always preserve photo import. No background scanning bypasses or indefinite camera use.
- **Compatibility**: Remote pairing requires online Relay even though camera QR reading is offline. Do not advertise it as Bluetooth-only proximity pairing.
- **License**: MIT attribution and full license text must accompany distributed CodeScanner binary/source as required; current Inbox does not ship third-party package.
- **Current stage**: candidate, no signed IPA, no main change, no migration, no production integration.
