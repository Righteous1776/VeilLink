# Risk and overlap

- PR #64 (global particle gesture) and PR #65 (per-control gestures) do not edit `VeilLink/Diagnostics/DeepTelemetry.swift`; Governor should test each hypothesis separately before combined integration.
- Recorder self-delegate is not proof of passivity; always-simultaneous can also affect UIKit gesture resolution. Default-off controls blast radius. Physical iOS15 testing mandatory.
- Existing persisted true preference remains honored. Old unpersisted default true now becomes false to protect normal touch responsiveness. UI raw-touch switch remains accessible under Owner Console.
- Opt-in diagnostic reduction loses passive raw traces until enabled; normal semantic black box remains.
- DeepTelemetry still swizzles UIApplication.sendAction and DiagnosticLogStore encodes on MainActor; separate main-thread audit needed if stalls persist. No protected subsystem change.
- No macOS compilation/device test performed. No direct product source edits or Actions.
