# Risks

## Protected surfaces

This proposal touches only presentation/theme state in `VeilLink/Core/AppearanceTheme.swift`.

It does not propose changes to transport, storage/schema, identity/key management, wire protocol, A9/A10 governance, workflows, release/signing, or version/build values.

The product file is not modified by this agent; the patch is advisory only.

## Cross-agent overlap

No direct file overlap was found with active legacy PR #4, #9, #10, or this agent's prior Inbox PR #14 at preparation time.

There is behavioral adjacency with UI/product-restoration work because many views consume the appearance singleton. This submission does not resolve or rewrite those lanes. The Integration Governor should re-check all active Inbox submissions and legacy evidence before batching.

## Behavioral risks

The main risk is an existing or newly introduced non-main synchronous consumer of `VeilAppearanceController.shared`. The proposed annotation would turn such access into a compile-time isolation diagnostic.

This is considered desirable signal rather than a reason to weaken isolation, but it can require a follow-up adaptation at the consumer during integration.

## Migration / compatibility risks

No data migration is involved.

SDK/toolchain behavior matters because SwiftUI protocol members have evolving MainActor annotations. The complete Xcode build is therefore mandatory even though the language-level singleton pattern passes a strict Swift 6.2 micro-compile.

## Performance / battery risks

None expected. Actor annotation has no meaningful runtime cost for the singleton's existing UI-thread usage.

## Security / privacy risks

None expected. No data handling, telemetry payload, credentials, message content, or permission behavior changes.

## Rollback strategy

Revert the one-line annotation if integration exposes an unacceptable call-site regression.

Do not replace it with `@unchecked Sendable` or a broad unsafe suppression without separate review. If a background consumer is legitimate, redesign that consumer or introduce a Sendable snapshot in a new proposal.
