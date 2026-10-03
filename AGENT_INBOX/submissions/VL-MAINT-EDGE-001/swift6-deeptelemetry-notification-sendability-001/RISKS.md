# Risks

## Protected surfaces

The proposal is limited to `VeilLink/Diagnostics/DeepTelemetry.swift`. It does not propose changes to transport, storage schema, identity/key management, wire protocol, A9/A10 governance, workflows, release/signing, or version/build values.

The product file itself is not modified by this agent; `PATCH.diff` is advisory only.

## Cross-agent overlap

No direct file overlap was found with the changed-file sets of active PR #4, #9, #10, or governance PR #12 when this proposal was prepared.

Because Inbox work is concurrent, the Integration Governor should re-check later submissions for:
- `VeilLink/Diagnostics/DeepTelemetry.swift`
- the same NotificationCenter observer callbacks
- any redesign of diagnostic actor isolation

If overlap appears, this agent does not resolve it.

## Behavioral risks

`nonisolated(unsafe)` suppresses compiler enforcement for the local immutable alias. Its safety depends on the existing observer contract `queue: .main`.

The main risk is future maintenance changing one of these observers to `queue: nil` or a background queue while leaving the unsafe alias in place. That would invalidate the proposal's concurrency assumption.

Mitigation:
- keep the assertion local rather than type-wide;
- retain `queue: .main` in every affected observer;
- add the queue invariant to review/acceptance criteria;
- prefer a future Sendable snapshot redesign if callback scheduling changes.

## Migration / compatibility risks

Low. No persistence, API, event-name, protocol, or serialized-format migration is involved.

Toolchain risk: integration must confirm `nonisolated(unsafe)` local bindings compile under the repository's exact Xcode/Swift toolchain and iOS deployment target.

## Performance / battery risks

Negligible expected impact. The patch adds only local immutable bindings and preserves the same number of tasks and observer callbacks.

## Security / privacy risks

No new data is captured. Existing `Notification` or UIKit object references are only aliased locally and passed to the same existing main-actor handlers.

No message plaintext, credentials, keys, or new diagnostic fields are introduced.

## Rollback strategy

If integration build/tests expose any actor/runtime regression, revert the single DeepTelemetry patch. No migration or cleanup is required.

A safer but more invasive fallback is to redesign the observers to extract Sendable value snapshots before crossing into the main-actor task, subject to a separate reviewed proposal.
