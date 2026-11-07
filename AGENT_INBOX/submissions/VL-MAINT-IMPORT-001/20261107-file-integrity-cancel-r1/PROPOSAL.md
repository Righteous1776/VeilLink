# Problem and Minimal Fix

Current main `2c5b5161027edff097b27fe3323d30f6ca3e430e` creates an untracked `Task` for provider materialization in `VeilFileIntegrityToolView` and stores only a parent `inspectionTask`. It then awaits `Task.detached { VeilFileIntegrityEngine.inspect(...) }.value`. Cancelling the view task on navigation away does **not** cancel that detached child. The hasher already checks `Task.checkCancellation()` per 512 KiB chunk, so the absent cancellation handoff defeats an existing safety mechanism.

This proposal:
1. Retains/cancels the file-provider materialization task; does not start hashing if navigation already cancelled the import; removes any staged snapshot in that path.
2. Marks the slot busy as soon as materialization starts, blocking duplicate user selections.
3. Propagates inspection parent cancellation to the detached hashing worker using `withTaskCancellationHandler`; existing `defer` removes the owned staging copy after the worker exits.
4. Adds a deterministic XCTest showing a pre-cancelled hash operation never returns a digest.

No changes to global file picker UTI permissions, provider coordination, wire v4, generic PDF/ZIP peer transport, SQLite, signing, UI theme, model data, or release number. Do not interpret the patch as a fix for all Files import failures.

## Acceptance
Apply only after Governor checks actual main tip; iOS 15 compile, XCTest, and a real large-file picker/dismiss/reopen regression are mandatory before merge. No manual IPA dispatch in this lane.
