# Proposal

## Goal

Remove the eight Swift 6 strict-concurrency diagnostics emitted by `DeepTelemetry.installNotificationObservers()` when UIKit `Notification` values or their `object` references are captured by `Task { @MainActor ... }`.

## Current problem

Current `main` builds successfully, but iOS CI run `37108237656` reports eight diagnostics in `VeilLink/Diagnostics/DeepTelemetry.swift` around lines 306-327. Xcode states that sending the callback `notification` into the main-actor task risks data races and notes that these diagnostics become errors in Swift 6 language mode.

The observers already specify `queue: .main`, so runtime delivery is constrained to the main operation queue, but Swift's static concurrency checker does not infer that queue contract as actor isolation.

## Proposed behavior

Keep every observer name, `queue: .main` registration, event name, metadata path, privacy filter, and asynchronous `Task { @MainActor ... }` hop unchanged.

Inside only the eight affected callbacks:

- keyboard show/hide callbacks create a local `nonisolated(unsafe)` alias of the `Notification`;
- text-field callbacks create a local `nonisolated(unsafe)` alias of `notification.object`;
- text-view callbacks create a local `nonisolated(unsafe)` alias of `notification.object`;
- the existing main-actor task consumes that alias.

This is intentionally a narrow compiler-boundary assertion rather than a redesign of telemetry scheduling.

## Architecture / implementation

The patch relies on one explicit invariant already present in source: every affected observer is registered with `queue: .main`.

`nonisolated(unsafe)` is scoped to a callback-local immutable binding. It does not make `DeepTelemetry` nonisolated, does not change the actor annotation of the class, and does not weaken any broader synchronization contract.

The existing `Task { @MainActor ... }` remains in place so event handling preserves its current asynchronous ordering relative to NotificationCenter delivery.

No helper API, public API, storage format, diagnostic event schema, or privacy behavior changes.

## User-visible impact

None expected. This is a compiler-safety maintenance change. Keyboard, text-field and text-view diagnostic events should continue to be produced exactly as before.

## Compatibility

- iOS behavior: unchanged.
- Swift 5 language mode under Xcode 16.x: syntax is supported by the Swift 6 compiler toolchain used by current CI.
- Swift 6 migration: removes the targeted sendability/isolation diagnostics without widening actor isolation across unrelated static theme or telemetry data.
- Persistence/network compatibility: not applicable.

## Alternatives considered

1. **Annotate broader callback or class surfaces with `@MainActor`.** Rejected because NotificationCenter's callback type remains nonisolated at the type-system boundary and broader actor annotations can create avoidable call-site churn.
2. **Replace the tasks with synchronous main-actor assumptions.** Rejected because that would alter event scheduling semantics and still requires an explicit assertion for non-Sendable callback payloads.
3. **Extract only fully Sendable metadata values before the task.** Viable but substantially more invasive because keyboard handling currently consumes `Notification.userInfo` and text lifecycle helpers consume UIKit object references.
4. **Ignore the warnings until Swift 6 mode is enabled.** Rejected because CI already identifies them as future errors.

## Acceptance criteria

- `VeilLink/Diagnostics/DeepTelemetry.swift` is the only proposed product file.
- All affected observers remain `queue: .main`.
- Existing `Task { @MainActor ... }` hops remain.
- Existing event names and telemetry metadata remain byte-for-byte behaviorally equivalent.
- iOS simulator build succeeds.
- Full XCTest inventory succeeds.
- Build logs no longer contain the eight targeted DeepTelemetry “sending 'notification' risks causing data races” diagnostics.
- No new strict-concurrency warning is introduced in DeepTelemetry.
