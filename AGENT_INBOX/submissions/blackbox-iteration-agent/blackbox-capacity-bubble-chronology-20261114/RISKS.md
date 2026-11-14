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


## R3 additional risks and coverage gaps

- **Only partial full-product coverage:** the seven local AI reducers, BLE transport and multiplayer Veilopoly bridge have code hooks. Arcade and story routes are launch-only. Offline Veilopoly engine finance/reducer, LAN, internet relay, community mesh, image/voice and background transport internals still require additional dedicated hooks; do not mark them deep-covered.
- **Telemetry overhead and retention:** Gomoku move-by-move and self-play batch records can increase write rate. BLE admission pressure is throttled; missing intermediate events must be counted separately before diagnosing an outage from an absence of entries.
- **Concurrent bridge lifecycle:** Combine observation of `GameSessionModel.$game` needs real Swift 6 actor isolation validation, subscription reset on restore, cleanup on room exit and identity switch, plus no false double counts.
- **Exact source compatibility:** App code must not be imported into the standalone Veilopoly SwiftPM package. Architecture must provide a host-facing typed event adapter before instrumenting offline economic decisions. UI view modifier additions may increase SwiftUI type-check cost.
- **Structured move data:** Gomoku board index and timestamps may expose strategy/timing patterns; treat exports as confidential even without chat contents. No full board frames or user-entered narrative text in black box.
- **Version and readiness:** no iOS compile/XCTest/IPA verification; PR remains Inbox-only draft and must not merge until Governor reviews other agents and a complete product integration gate passes.
