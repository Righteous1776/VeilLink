# Integration risks and overlap

1. **Shared theme root**: AppearanceTheme.swift and AppTheme.swift are core display surfaces. New `.forge` is additive, but owner must review exhaustive switches/new model persistence and day/night behavior before merge.
2. **PR #231 supersedence**: existing mechanical animation proposal edits `NearbyView.swift` and `AgentStatusView.swift`; do not apply both patch sets independently. This FORGE proposal replaces their appearance-level intent with theme-scoped UI and should become the canonical theme candidate; the older PR remains an audit reference until Governor decides.
3. **PR #229 dependency**: root global particle deletion in `VeilLinkApp.swift` is separate. FORGE itself introduces no root-level particle system but cannot guarantee a particle-free app until #229 is integrated.
4. **Theme scope**: current hard-coded surface colors in nested game/third-party screens may not fully inherit FORGE palette. This R1 installs the shell and selected system panels, not a claim that every hard-coded UI has been redesigned. Audit remaining screens after actual iOS visual review.
5. **Legacy device/SwiftUI**: TimelineView, gradient layers and stator ticks require iOS simulator and physical-device validation. Existing VeilMotionPolicy and app lifecycle gates minimize but do not prove zero performance impact.
6. **Data truthfulness**: RF/CPU rotor only reflects state; cannot infer clock rates/search depth; actual BLE health score is a diagnostic scalar, not signal strength or throughput.
7. **Theme token integration (corrected 2026-11-14)**: R1 initially referred to unavailable `VeilTheme.metalTop` and `VeilTheme.metalBottom` accessors. The Inbox patch has been corrected to use the existing appearance palette's metal fields. Still requires a full Xcode compile before promotion.
8. **No release authority**: Inbox-only five-document submission; no product files, main, version, signing, workflows or IPA changed.

9. **R2 shared motion-policy surface**: `VeilMotionKit.swift` now receives a FORGE-specific branch in `VeilSpatialPressModifier`, bypassing only the decorative zero-distance drag gesture. This is a global modifier definition, though behavior changes only under the selected FORGE theme; verify parent scrolling and button taps. The same source file disables infinite border rotation in FORGE only.
10. **Game agent overlap**: user's screenshots reference `GameLobbyView.swift` and ECLIPSE search/training UI currently being developed separately. R2 deliberately does not edit these files; integration Governor must coordinate later component adoption.
11. **Screenshot state is not source state**: screenshots capture an installed app with global dust/particles. The image alone does not prove frame-time causes; isolate #229 as root particle removal before claiming full elimination.


12. R3 differentiation: Five distinct actuators could create visual competition during simultaneous state changes. Limit them to their local panels and review hierarchy in real iPhone screenshots.
13. Odometer dependency: uses existing VeilOdometerNumber from VeilMotionKit, not a newly reimplemented digit engine; test multi-digit changes and VoiceOver.
14. LAN state semantics: secure peers take priority over merely connected peers. This represents observed route availability, not selected active transport, file-transfer percentage or negotiated bandwidth.
15. Reduced motion: CPU shutters/LAN/health use existing short VeilMotionPolicy animations and no independent scheduler. RF has a single conditional TimelineView. Explicitly inspect OS Reduce Motion and performance overrides on device before integration.
16. All state labels are actual app-derived values; no fabricated load/speed, no root overlay, no new gestures or persistent background work.


17. R4 chat is a high-interaction surface: the proposed patch deliberately changes only presentational components. Do not interpret this as resolving preexisting keyboard obstruction, inverted message order on device clock skew, or scroll-to-top regression. These need separate functional investigations and tests.
18. FORGE message status has three discrete detents for QUEUE/TX/ACK and explicit HOLD/STOP/ERR labels; it is an exact status symbol, not a three-phase progress percentage. Do not mistake .sending for acknowledged delivery.
19. ChatView gains one observed theme controller; the many MessageBubble instances receive a Bool instead of each subscribing to the global theme object. Still profile for long histories and iOS theme switching.
20. Send plunger preserves native Button hit testing and a fixed 36pt footprint; footer top-line overlay introduces no additional height. Validate the keyboard safe area and VoiceOver on physical devices.
21. Global-message animation disable applies only to FORGE. Other themes' original insertion and message count transitions are deliberately preserved.
