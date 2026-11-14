# Risk register / R2

1. **Cannot guarantee five nights**: 512 MiB is a raw budget, not a time retention policy. High-frequency UI/render/transport activity can overwrite oldest segments. Persisted evictions + earliest/latest record times increase honesty but don't prevent loss.
2. **Temp ZIP capacity**: a full 512 MiB dataset can temporarily use much more than 512 MiB during snapshot staging and compression. Export may fail or be difficult to share from an iPhone. Segmented compressed export remains a follow-on milestone.
3. **Incomplete global instrumentation**: a feature registry audit only covers feature-library entries. Other legacy modules, model engines, transports, background workers and future features still require typed, reviewable hooks. Unobserved packs are not proof of absence of telemetry or incorrect functionality.
4. **Data privacy**: even message order/timestamps/direction can reveal communication patterns. No text, content hashes, remote app data, private keys or unconsented audio should be captured. User must explicitly export sensitive local files.
5. **Permissions:** owner diagnostics controls do not grant system-wide access, root, sandbox escape or entitlements. TrollStore marker alone is not proof of elevated privileges; each capability needs verified authorized support.
6. **I/O wear, thermals and battery**: larger multi-day log volume and 16 MiB segment reads may affect low-storage or constrained devices. Optimize/benchmark before rollout.
7. **Runtime correctness**: SwiftUI compiler has previously timed out on ConversationViews, and owner UI changes require exact macOS Xcode/XCTest. Unified diff replay is NOT compiler or runtime validation.
8. **Rotation counter crash window**: a crash between oldest-file deletion and best-effort JSON counter write may undercount one eviction; durability tests and transactional state improvements are needed before calling it loss-proof.
9. **Governance overlap**: earlier diagnostics-agent preconsent-blackbox-ios15-20261024 plus #64/#66 instrumentation may overlap. Avoid self-merge or silent arbitration.
10. **Public repo**: Do not include actual diagnostic logs, private user messages, credentials, key material, IPA or exported runtime artifacts in the Inbox.
Status: DRAFT proposal; product not applied; CI/physical-device testing NOT_RUN.
