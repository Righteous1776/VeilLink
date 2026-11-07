# Last-round nonduplicate fix – brightness NotificationCenter snapshot storm

### New P1, not overlapping prior repair scope
Existing `DeepTelemetry.swift` registers UIScreen.brightnessDidChangeNotification and schedules a MainActor full system snapshot for **every** tiny brightness event. On iPhone7 automatic-brightness changes produced 459 `system.snapshot` events during this archive; expensive system snapshot also samples `volumeAvailableCapacityForImportantUsage`. This is independent from PR #137's log writing and BLE/peer throttling.

### Actual source changes in PATCH.diff
- Add portable `DeepTelemetryBrightnessSnapshotPolicy`, with 2-second minimum cadence + significant 0.02 brightness delta and invalid sample guards.
- Store last accepted brightness/time in the existing MainActor `DeepTelemetry` class and route brightness observer to guarded method.
- Preserve all startup/thermal/battery/lifecycle, periodic and forced incident system snapshots unchanged. Do not mute true crashes or user taps.
- Add dedicated XCTest file with first sample, suppression, boundary and invalid value regression cases.

### Explicitly not touched
No `DiagnosticLogStore.swift`, `RuntimeDiagnosticsBridge.swift`, `BLETransport.swift`, `AppModel.swift`, `SessionCoordinator.swift`, SQLite/schema, encryption, UI root, notification permissions or workflows. No duplicate of #137/#145/#146.

### Gate
Source patch validated textually against exact main; pure scalar gate tests evaluated in JavaScript. Apple SDK compile, XCTest, iPhone7 performance and watchdog repro NOT_RUN. DO NOT claim the 1,081 stalls are fixed by brightness dedup; historic watchdogs require independent profiling.
