# Proposal

## Goal

Remove the Swift 6 warning caused by a mutable local variable, `effectiveLimit`, being captured by the nested main-queue closure in `ConversationViews.reload()`.

## Current problem

Current main CI continues to report:

`ConversationViews.swift:731:76: warning: reference to captured var 'effectiveLimit' in concurrently-executing code`

The warning is reproducible in the latest completed main CI after Inbox activation and machine-gate rollout.

Inside the background `DispatchQueue.global(...).async` block, `effectiveLimit` is intentionally mutable while the loader expands the recent-message window to recover complete mini-game session history. The same mutable variable is then captured by `DispatchQueue.main.async` for updating `messageWindowLimit`.

Swift 6 treats referencing a captured mutable variable from concurrently executing code as unsafe.

## Proposed behavior

After background pagination is complete, freeze the final value into an immutable value:

`let resolvedLimit = effectiveLimit`

The main-queue closure captures only `resolvedLimit`, an immutable `Int`, rather than the mutable `effectiveLimit`.

## Architecture / implementation

The proposal changes no pagination logic.

Execution remains:

1. Start with the current message window limit.
2. On the background queue, fetch a recent page.
3. If mini-game events reference a session whose invite is outside the current page, grow `effectiveLimit` up to the device profile maximum and refetch.
4. Once that background computation is complete, snapshot the final limit into `resolvedLimit`.
5. Build mini-game session state from the loaded messages.
6. Hop to the main queue and update UI state.
7. Use `resolvedLimit` when monotonically increasing `messageWindowLimit`.

The snapshot is intentionally taken only after all mutations to `effectiveLimit` are complete.

A Swift 6.2 strict-concurrency typecheck was used to validate the immutable nested-closure capture pattern under `-swift-version 6 -strict-concurrency=complete -warnings-as-errors`.

## User-visible impact

None expected.

Message loading, pagination bounds, mini-game session reconstruction, loading indicators, and the visible chat history should behave exactly as before.

## Compatibility

- No API or serialized format changes.
- No DatabaseStore changes.
- No change to device performance profile values.
- No iOS availability changes.
- Compatible with existing iOS 15 deployment requirements.

## Alternatives considered

1. **Capture `effectiveLimit` directly.** Rejected because this is the current Swift 6 warning.
2. **Move all pagination work onto the main queue.** Rejected because it would regress responsiveness.
3. **Refactor the whole loader to Swift structured concurrency.** Potentially valuable later, but far broader than the warning being fixed.
4. **Mark surrounding data unsafe or Sendable.** Rejected because the warning is specifically about mutable capture and can be solved with an ordinary immutable value snapshot.
5. **Combine this task with the three DatabaseStore non-Sendable warnings in the same file.** Rejected because those touch a different concurrency boundary and should be reviewed separately.

## Acceptance criteria

- Proposed product diff touches only `VeilLink/UI/ConversationViews.swift`.
- The background pagination loop is behaviorally unchanged.
- `effectiveLimit` is still the mutable working value inside the background computation.
- A final immutable `resolvedLimit` is captured by the main-queue closure.
- The `effectiveLimit` Swift 6 warning disappears.
- The proposal does not claim or attempt to fix the three existing DatabaseStore non-Sendable warnings in the same file.
- Simulator build passes.
- Full XCTest passes.
- Recent-message pagination and mini-game session reconstruction remain correct.
