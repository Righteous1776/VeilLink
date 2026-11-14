# VeilScreen system-level BLE screen share — R0

Product flow: 聊天区 > + > 邀请屏幕共享 > 对方接受或拒绝 > 共享方用苹果系统选择器明确许可 > 后台系统屏幕视频采集 > 端到端加密 BLE 低帧率转发 > 观看方可放大/停止。双方随时结束。**不传音频，不请求摄像头，不存视频，不写聊天记录，不上传网络**。屏幕像素本身可能包含个人内容，不能承诺自动隐藏所有隐私信息。

**Currently implemented**: Swift protocol core, 18-byte typed control packet, per-share UUID, 384-byte chunks / 32KiB frame cap / 86-chunk cap, 7s bounded single-frame reassembler, replay/cross-share discard, 3-20KiB target budgets and 0.2-2fps adaptive target, grayscale JPEG CMSampleBuffer compressor candidate. These are NOT connected to live screen capture.

**Integration plan (only by Governor):**
1. ConversationViews.swift ChatView '+' menu (approx lines 667-718) add invitation action after state coordinator wired. Add separate SwiftUI ViewBuilder for invitations to avoid prior giant ChatView type-check failure. Incoming invite not a persisted normal message bubble.
2. AppModel.swift creates transient screenShare coordinator; SessionCoordinator.swift + WireCodec.swift allocate new authenticated *ephemeral* control/media types with key-separated AEAD, capability negotiation and strict peer trust. Never use WireChatContent or attachment/durable outbox. Preserve protocol v4 compatibility with peers that do not support screen sharing.
3. BLETransport.swift put image packets in lowest queue priority, reserve bandwidth for chat/controls, cap backlog, drop outdated frames before retries. No Internet fallback without approval.
4. iOS 26+ ScreenCaptureKit SCContentSharingPicker + SCStream video-only sample output, explicit consent, system recording indicator and stop. Xcode target requires NSScreenCaptureUsageDescription and UIBackgroundModes screen-capture, conditioned on SDK validation; pre-iOS-26 ReplayKit Broadcast Extension as separately gated fallback. Keep iOS15 deployment stable and version/build V29.1/b67 unchanged.
5. iOS 26 Bluetooth background may use a Live Activity with existing bluetooth-central/peripheral modes; Apple does NOT promise unlimited execution. TrollStore true-background mode cannot substitute for real tests.

**Targets not guarantees**: 240-540px output, 3-20KiB per changed frame, 0.2-2fps, no audio. Receiver zoom improves characters' rough outlines. If text remains unreadable, prefer ROI/tile refresh over pretending whole-screen 240px is sufficient. Never log frames, pixels, OCR, app titles, URLs or frame hashes; count bytes/drops only.

Authoritative Apple docs: https://developer.apple.com/documentation/screencapturekit ; https://developer.apple.com/documentation/xcode/configuring-background-execution-modes ; https://developer.apple.com/library/archive/documentation/NetworkingInternetWeb/Conceptual/CoreBluetooth_concepts/CoreBluetoothBackgroundProcessingForIOSApps/PerformingTasksWhileYourAppIsInTheBackground.html
