# P0/P1 touch arbitration audit — source proposal

User reports controls/scroll/sliders/drag pieces failing after Build60. The highest shared source culprit, global particle DragGesture, is in separate Draft PR #64; do not duplicate/merge without Governor. Source reviewed against main 501ef814a0a9bea41419fe2d9f48315371b30320.

## 10 bounded fixes across 9 files

1. `VeilReleaseActivationView`: remove whole-page onboarding DragGesture competing with scroll/buttons/legal form. Back/Continue buttons remain. Swipe-to-page temporarily disabled pending scoped swipe testing.
2. `ToolCenterView`: PTT press cleanup now runs on navigation exit, inactive/background and loss of recipients; prevents stuck pressed state and continued transmit when onEnded is swallowed.
3. `MiniGameViews` Gomoku: reject release events after >10pt finger displacement; no accidental placement on swipe.
4. `MiniGameViews` Xiangqi: reject >10pt displacement and disable entire invisible board gesture overlay while !enabled, allowing parent input.
5. `PlatformerView`: single jump request per hold, release on gesture end, pause, background and exit.
6. `TacticalLandscapeShellV2`: minimumDistance 0 enables stationary map taps as well as existing route drag. Field-specific gesture, not global.
7. `FullScreenImageViewer`: exclusive tap recognizer resolves ambiguous single/double tap handler overlap while keeping zoom/pan.
8. `SignalDiveLabView`: stop thrust and reset stick state on background or navigation exit.
9. `BlackoutDistrictLabView`: stop drive + repair on background or navigation exit.
10. `VeilAppleMaterialEngine`: decorative Apple Soft stroke overlays explicitly .allowsHitTesting(false).

**Not claims of device-verified fixes:** Inputs depend on SwiftUI iOS 15 recognizer arbitration and need iPhone7 tests. Do not change Keychain, SQLite, BLE protocol, TrollStore permissions, model, release or version. Patch is advisory and stays in Inbox. All installation and recovery data unchanged.
