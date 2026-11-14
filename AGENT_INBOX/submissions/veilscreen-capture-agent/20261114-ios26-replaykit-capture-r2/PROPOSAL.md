# VeilScreen R2: Real system-wide capture candidate for iOS 15+

## Why R1 would not work as shipped
Newer ScreenCaptureKit full display capture on iOS starts with iOS 27; the user's iOS 26 devices require ReplayKit Broadcast Upload Extension. R1 also deliberately lacked system capture code and authenticated SessionCoordinator real-time media integration. R2 fixes the capture side but does not magically solve host app suspension / BLE media encryption binding.

## Added concrete Swift components
- `VeilScreenCapturePolicy.swift`: iOS 26 vs 27+ route selection, capture pacing, strict freshness.
- `VeilScreenBroadcastSecurity.swift`: signed App Group/keychain configuration and ephemeral device-only AES key acquisition.
- `VeilScreenEncryptedMailbox.swift`: one encrypted, replaceable local IPC frame with authenticated session UUID; 44 KiB ciphertext cap and destructive read.
- `VeilScreenReplayKitEncoder.swift`: video-only decimation/gray JPEG with frame payload budget; no audio.
- `VeilScreenBroadcastUploadHandler.swift`: actual `RPBroadcastSampleHandler` callback receives external app display video, throttles and encrypts to App Group. Fails closed on key or app-group errors, invalid consent/session, and timeout.
- `VeilScreenLegacyBroadcastHost.swift`: prepares 30-minute, per-invite one-time encryption key before OS screen broadcast consent.
- `VeilScreenLegacyBroadcastPicker.swift`: native ReplayKit system broadcast picker with microphone control hidden (audio dropped even if otherwise present).
- `VeilScreenReplayKitConsentView.swift`: explicit local consent/stop surface, no false LIVE state.
- `VeilScreenLegacyMailboxPump.swift`: off-main decrypt/read, first-frame confirmation callback to R1 READY state, no frame send before READY-ACK, bounded low-priority R1 scheduler.

## Dependency and integration status
Build dependencies on R1 Draft PR #232 (`VeilScreenShareWire` v2, bounded BLE scheduler, R1 sender/receiver state machine and views). R2 does NOT yet add the SessionCoordinator encrypted screen-share wire types, AppModel hooks, or change `project.yml`, `Info.plist`, or signing — those are protected surfaces requiring a Governor-owned integration branch and iOS CI. Without that integration it is code, **not a functioning device feature**.

## Apple primary sources
https://developer.apple.com/documentation/replaykit/rpbroadcastsamplehandler
https://developer.apple.com/documentation/replaykit/rpsystembroadcastpickerview
https://developer.apple.com/documentation/screencapturekit/capturing-screen-content-on-ios
https://support.apple.com/en-gb/guide/security/seca5fc039dd/web

## 2026-11-15 scope correction
Both testing phones have **iOS 15**, per Owner. ReplayKit Broadcast Upload extension remains the intended public capture path, with target deployment `15.0`. R2.1 corrects the ReplayKit Swift override parameter type to `[String: NSObject]?` (previous `[String: NSCoding]?` does not match the SDK declaration). Need Xcode 15.0 deployment and two real iOS15 phones before promoting.
