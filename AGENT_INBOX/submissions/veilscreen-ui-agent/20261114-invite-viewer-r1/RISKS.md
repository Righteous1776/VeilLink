# Scope, risks, overlap, and non-claims

1. **No system capture adapter or authenticated BLE cryptography is connected.** The injected hooks are interfaces: treating them as working production transport would be a critical product and privacy defect.
2. **No OS consent bypass.** TrollStore true-background / true-foreground is an optional device-side experiment, not proof that iOS grants capture or indefinite transport. Apple user-visible picker and consent controls remain required.
3. R0 and R1 proposals overlap (R0 PR #226). R1 chunk v2 is intentionally non-compatible with prior R0 chunk v1; use exactly ONE Governor-selected candidate, no dual merge.
4. No direct edits to product `ConversationViews.swift`, `AppModel.swift`, `SessionCoordinator.swift`, `WireCodec.swift`, `BLETransport.swift`, `Info.plist`, signing, version/build, workflows or A9/A10 governance. They are protected and overlap existing UI/transport maintenance lanes.
5. Even when text is distinguishable in a zoomed preview, loss of pixels is irreversible; 240px full-screen mode may not allow fine text readability. Region-of-interest tile refinement must be performance-tested separately.
6. Source video can contain notifications, private data and system interface. No metadata filters can promise all private content is excluded. Do not write pixels, OCR, frame hashes or app titles to blackbox or analytics. Only counters allowed.
7. UI SwiftUI components are **syntax-checked only** on Linux; no Xcode Apple SDK compiler or iPhone/device available here. All hardware/background/permission assertions stay UNKNOWN, not PASS.
8. The current workflow only checks JPEG start/end bytes; production MUST validate full decode and pixel dimensions BEFORE marking first frame live to avoid corrupt content or decompression bombs.
9. Current sender scheduler `didAdmit` means local BLE enqueue, not actual remote reception. Real link needs queue metrics, congestion and latency measurement. Video is disposable, not retransmitted from durable chat storage.
10. Existing R0 smoke used standard `assert` under `-O`, which can be removed by optimization. R1 uses `precondition`, newly executed in optimized builds.
