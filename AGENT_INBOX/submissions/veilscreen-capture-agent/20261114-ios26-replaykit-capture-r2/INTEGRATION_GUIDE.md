# VeilScreen R2 — Governor-only integration guide

This is an **implementation proposal**, NOT a signed, compiled or working two-phone screen-share feature. Do not ship its ReplayKit target until a real Apple iOS 15 build, signing and physical-device checks pass.

## Current source baseline
- Canonical repository: `Righteous1776/VeilLink`, main `af3d823546c288169d19cb3033a6111977d28bd7`, v29.1 Build 67.
- R1 UI/control dependency: Draft PR #232, `AGENT_INBOX/submissions/veilscreen-ui-agent/20261114-invite-viewer-r1/`, frames v2.
- R0 PR #226 (v1 frame protocol) must NOT be imported together with R1/R2.
- File additions below are proposals under the R2 Inbox; no source/protocol entitlements changed on main.

## Integration order
1. Review and integrate only accepted R1 wire/state/scheduler/view candidates on a Governor integration branch. Reuse `VeilScreenShareWire.swift`, `VeilScreenBLEScheduler.swift`, the `READY/READY-ACK` control workflow and receiver viewer UI. Do not import R0 frame v1.
2. Add the R2 source files from `FILES/` to VeilLink/ScreenShare and VeilLink/UI. **Except** `VeilScreenBroadcastUploadHandler.swift`, which must be compiled only by the new ReplayKit Broadcast Upload extension. Host target already recursively includes VeilLink; exclude handler source explicitly in `project.yml`.
3. Add ReplayKit broadcast upload extension via XcodeGen project.yml, following the target fragment in `CONFIG/project-target-fragment.yml`. The exact YAML is a design overlay, not a ready-to-merge mutation of project.yml. Embed extension in VeilLink app target and configure the proper signing team. Use app group plus shared keychain group entitlements for BOTH signed targets. App Group must be registered in the developer account and must be checked against actual provisioned entitlements. Unsigned IPA is insufficient for cross-process keychain/app-group tests.
4. Add corresponding `VeilScreenAppGroup` and `VeilScreenKeychainGroup` keys to the **host** Info.plist. Also use `CONFIG/VeilScreenBroadcastUpload-Info.plist` for extension. Validate actual build-time expansion of `$(AppIdentifierPrefix)`; `load()` intentionally fails closed when unresolved.
5. In ChatView existing `+` menu (ConversationViews.swift ~lines 667-718), add a single `邀请屏幕共享` option, not a nested intrusive gesture. Invoke existing VeilScreen R1 workflow, which must be bound to the currently authenticated BLE-only peer. Present a separate sheet for `VeilScreenReplayKitConsentView` once ACCEPT is authenticated, not on tapping invite. Do not add more complex modifiers to ChatView giant body; extract a presentation property.
6. On session accepted, host creates temporary `VeilScreenBroadcastHost.prepare(sessionID:)`, then the local user taps the system `RPSystemBroadcastPickerView` and selects `VeilScreen` broadcast. `RPBroadcastSampleHandler` receives video-only CMSampleBuffer frames and writes ONE AES-GCM encrypted replaceable frame to App Group. No microphone or audio samples are attached or forwarded. Temporary ciphertext on disk is deleted on take/stop/expiry cleanup; it is not a saved video recording.
7. Host `VeilScreenLegacyMailboxPump` polls off the main thread and validates encrypted mailbox frames, then emits `didObserveFirstCaptureFrame(sessionID)`. This callback must call R1 `captureDidStart` to send READY only after the extension produces a real frame. `canSendVideoNow` must check sender state `phase == .live` after authenticated READY-ACK. The pump sends media only through authenticated session, encrypted by SessionCoordinator using a domain-separated screen-media AEAD context, never as normal chat messages.
8. WireCodec / SessionCoordinator require a dedicated v4-compatible optional capability and typed E2EE screen-control + screen-media envelope handlers (protected protocol changes; Governor arbitrates feature bits and backward compatibility). Every inbound media packet must be bound to the current authenticated session, exact contact identity and share session UUID and must pass anti-replay/size limits. BLETransport `.bulk` low priority and high-priority chat reserve must be observed. Receiver assembles and displays only a validated JPEG; no persistence or import into backups.
9. On disconnect/revoke/stop or identity change: send STOP when possible, stop broadcaster via system UI or extension, invalidate App Group session, delete shared keychain key and encrypted mailbox, empty scheduler/decoder/preview, and require new mutual consent to restart.

## Important architecture limit
For iOS 15, ReplayKit upload **extension** may continue producing encrypted frames in the background, but VeilLink host process BLE send/poll may be suspended. The single-slot mailbox prevents unbounded storage but **does not guarantee live delivery while host is suspended**. TrollStore foreground/background modes are device-specific; do not advertise verified always-on BLE. iOS 27+ ScreenCaptureKit is a separate future adapter, not provided by this iOS 26 R2 implementation.

## Non-negotiable privacy
- Both participants agree; recording-side OS consent visibly shown.
- No automatic screen capture; remote peer cannot initiate device capture without local action.
- Screen pixels inherently reveal visible content; no claim that screenshots hide notifications or private data.
- Never log JPEG, screen text, hashes or app names. Diagnostic counters may include frame ID/count/bytes only, with care.
- App Group single-file ciphertext is transient local disk IPC, **not** zero disk writes. Do not claim otherwise.

## iOS15 compatibility amendment (R2.1)
Owner confirms both iPhones run iOS 15. Minimum target in `project-target-fragment.yml` is already `15.0`. `RPBroadcastSampleHandler.broadcastStarted` must override `([String: NSObject]?)` exactly; R2.1 fixes this compiler-blocking mismatch. `RPSystemBroadcastPickerView` and Broadcast Upload extensions operate through user-initiated system consent. No iOS26-specific ScreenCaptureKit implementation is linked into this target.

On iOS15, Core Bluetooth state preservation/background modes are event-driven and cannot promise continuous 0.4 FPS BLE transfers when host is suspended. The ReplayKit extension receiving video is a different process and does not grant ongoing host runtime. The pilot is not accepted until actual signed iOS15 sender+viewer testing demonstrates video reception and stop/cleanup.
