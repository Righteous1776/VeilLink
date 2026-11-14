# Risk / Overlap Review

- Dependency: Draft PR #229 removes app-wide particles. This submission does **not** remove the root particle overlay. Governor must integrate both if the owner's final intended UX is to have no global particles.
- Concurrent UI lanes may touch `NearbyView.swift` or `AgentStatusView.swift`; coordinate in Issue #6 and inspect exact SHA diffs before the integration branch applies this proposal. Never overwrite other agents' changes.
- Existing historical #64 touch/particle proposal affects root gesture handling but is logically superseded by #229's removal. This proposal contains no root gestures or app event modifiers.
- Rendering complexity: 24 static stator bars + two moving segments in up to two tiny local status views. TimelineView is clamped to 12Hz, paused under reduced motion, idle, background, power constraints; device profiling is still required.
- `VeilMotionPolicy.allowsContinuousDecorativeMotion` may suppress animation on older devices; device UX must remain meaningful with static indicators. God Mode never overrides OS Reduce Motion for this actuator.
- BLE healthScore is a link health score rather than battery, rate or RSSI: never label this bar with fabricated speed/transfer completion.
- No Apple build yet: SwiftUI compile and localization/line wrapping remain pending.
- No main/IPA/release/version/signing changes permitted from this Inbox candidate.
