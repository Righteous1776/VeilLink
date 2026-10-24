# P0 candidate: opt-in UIWindow touch recorder and synchronized removal

## Source evidence

`DeepTelemetry.install()` currently adds a custom `PassiveTouchRecorder: UIGestureRecognizer` directly to visible `UIWindow` objects, independent of `rawTouchCaptureEnabled`. Its default is **true** on a fresh install. The Owner Console toggle changes UserDefaults and logging but **does not remove** the UIWindow recognizer. The recognizer remains possible until touch end/cancel. `cancelsTouchesInView=false` and no touch delays do not by themselves prove absence of recognizer competition. This is a high-priority **unverified root-cause hypothesis**, not evidence that it blocked any specific slider.

## Proposed changes

1. Default raw window touch tracing to false on fresh installs, preserving explicit persisted owner settings.
2. Synchronize installed window recorders immediately when owner toggles raw-touch logging. Enabled => one recorder per visible window; disabled => remove every recorder.
3. Synchronize on repeated `install()` and foreground reactivation to cover new/hidden windows.
4. Opt private recorder into simultaneous gesture recognition. Do not delay or cancel view touches. UIKit iOS15 arbitration still needs actual tests.
5. Opt-in `ui.raw.cancelled` event records touch count only, no location, content or identifiers.

Independent of PR #64 root particles and PR #65 per-control gestures; Keychain/SQLite/Wire/A9/A10 unchanged.
