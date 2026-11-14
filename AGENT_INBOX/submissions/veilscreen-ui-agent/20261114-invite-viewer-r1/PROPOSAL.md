# VeilScreen R1: invitation, consent, receiver and bounded BLE frame transport

## Source basis / primary integration surface
The canonical main as reviewed is VeilLink V29.1 Build 67, `af3d823546c288169d19cb3033a6111977d28bd7`. In current `VeilLink/UI/ConversationViews.swift` the chat `+` menu lives inside `ChatView` around the 670–720 source region. `AppModel` constructs `SessionCoordinator` and `BLETransport`; current `WireCodec` v4 switch has `pttControl`, `pttAudio`, `controlEvent`, `controlReceipt` but no screen-share lane. None of those product files are modified by this submission.

## UX 1: Chat + -> Invitation
- Add a **real enabled action only after AppModel has an authenticated screen-share coordinator**, guarded by peer capability and live BLE session. Never launch a fake working invite before authenticated transport exists.
- Outgoing invitation card: “已发送邀请”, 60-sec expiration, cancel; do not write invite to chat SQLite or durable outbox.
- Receiving trusted peer sees card **接受观看 / 拒绝**. Accepting does NOT authorize peer capture. Incoming invite never triggers screen capture or remote control.
- After remote accept, sender sees a separate preflight consent sheet, explicit button **继续到苹果系统授权**. Use Apple-provided SCContentSharingPicker on a supported runtime; this custom sheet is not a substitute for OS capture permission.

## UX 2: active view
- System picker opened is **connecting**, not live. `captureDidStart` needs an actual OS capture callback, not a button press.
- Control handshake: `invite -> accept -> OS capture start -> ready -> readyAck -> sender live -> authenticated complete first frame -> receiver live`.
- Sender can explicitly STOP; viewer can stop watching; a stop releases capture and last image buffers. Duplicate READY yields fresh READY_ACK. Expired invite, false peer, wrong UUID, early image, stale replay, and offline session are rejected.
- Receiver page has a top bar and a visible **结束观看** control, last-frame-age label, no-audio/storage text, pinch zoom, double-tap zoom and drag. Stale frame shown with “画面更新延迟”, never labeled fresh.
- Entire screen content may expose notifications/private text: preflight warns sender; no auto permission bypass, hidden observation, audio capture, camera, cloud uploads or local media persistence.

## Reliability/security improvements over R0
1. R1 chunk protocol version 2, 64-bit monotonic frame ID (33-byte header) vs R0 32-bit. R0 media packets MUST NOT be interpreted as R1.
2. At most 32KiB image / 86 chunks / 1 assembled frame, 384B per chunk, seven-second assembly expiry. Out-of-order chunks supported; stale/replayed frames dropped; wrong UUID rejected.
3. Sender scheduler has max two compressed frames in memory, lower-priority video, 8KiB backlog stop, newest waiting frame replacement, and no cursor advance until the BLE queue reports admission. It does not pretend that queue admission is radio delivery; missing frames are disposable.
4. `VeilScreenSessionWorkflow` is a pure Foundation adapter with dependency-injected **authenticated BLE / AEAD send / OS picker / stop** callbacks. A transport mock exercises the whole control-plane state flow; the production hooks remain UNWIRED.
5. Invite is resent every 3s until deadline; repeated invite is idempotent and re-ACKs an accepted invite. READY repeats every 2s until READY_ACK, with 15s timeout. Viewing stalls after 8s without fresh frame. Stop wipes current frame.
6. Unit smoke uses `precondition` rather than `assert`: with Swift `-O`, normal asserts may be optimized away. R0's earlier PASS is not treated as proof that all checks executed.

## Integration milestones (Governor only)
1. Add a feature-capability negotiation that is signed/validated for the current E2EE peer and wire-v4 compatible, and a dedicated encrypted ephemeral wire kind. Verify encryption uses unique authenticated nonce/counter and an AEAD context distinct from chat, PTT and attachments. Never route screen bytes through `WireChatContent`, Chat SQLite, the reliable message queue, backups or blackbox.
2. Inject a coordinator into `AppModel`, connect `VeilScreenSessionHooks` to current secure BLE link and send acceptance callback. This is the only path that may enable the chat `+` action. Keep UI in `VeilScreenShareViews.swift` instead of inflating `ChatView`'s already large ViewBuilder.
3. In `ChatView` `+` menu insert `Button { model.screenShare.requestInvite(to: conversation.peerIdentityID) } label: { Label("邀请屏幕共享", systemImage: "rectangle.on.rectangle") }` only after `screenShare` exists and sends verified packets. Bind transient incoming/outgoing snapshots to a visible card outside the persisted MessageBubble history. This line is **illustrative, not a compiling patch yet**.
4. Bind ScreenCaptureKit `SCContentSharingPicker`/`SCStream` video-only on validated iOS 26 SDK, user-initiated picker/stop, output `CMSampleBuffer -> VeilScreenFrameEncoder -> VeilScreenBLEScheduler -> E2EE BLE`. Report actual capture callback; do not invent `SCStream` API signatures without Apple iOS build. Setup `UIBackgroundModes=screen-capture` and screen usage description only with SDK/entitlement verification. Pre-iOS26 fallback is separately scoped.
5. Receiver: after replay and cross-peer checks, decrypt, assemble, validate dimensions/codec and decode image to memory, then update `VeilScreenViewerView` via main actor. On stop, identity change, system revocation, link disconnect or malicious-frame rejection clear displayed buffers. Show explicit warnings if UI text not readable at link throughput; zoom alone cannot recreate details removed by compression.
6. Run actual iOS/arm64 build and XCTest, then two-device Bluetooth-only acceptance, app switch/background, screen lock, rotation, consent revoke, 10-minute thermal/throughput and chat-latency tests BEFORE production promotion.

## Scope boundaries
The complete R1 candidate is a **working isolated native UI component + control-plane mock and validated Swift protocol/scheduler**, not yet a working iPhone screen-share application. This PR is Inbox-only by VeilLink governance. No changes to main, wire protocol production, E2EE implementation, Bluetooth permissions, release or IPA.

Apple SDK references:
- https://developer.apple.com/documentation/screencapturekit
- https://developer.apple.com/documentation/ScreenCaptureKit/SCContentSharingPicker
- https://developer.apple.com/documentation/BundleResources/Information-Property-List/UIBackgroundModes
