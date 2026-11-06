# Risks

## Protected surfaces

- The patch intentionally does not change Wire v4 or the 3MB protocol ceiling. It adds only a sender-side selection policy.
- Startup instrumentation is observational. It must not be treated as evidence that an initialization item is safe to defer.

## Cross-agent overlap

- PR #129 changes the imported-file staging lifecycle and can overlap `ConversationViews.swift` at the image-import caller. Reconcile both patches on the integration branch.
- PR #64 contains older startup-diagnostic work. Use the Build64 anchors in this patch rather than force-applying older hunks.
- Batch A / PR #137 is an ordered behavioral predecessor; it has no direct file conflict but should be applied before interpreting image throughput results.

## Behavioral risks

- An image that would have sent over BLE at 0.8–3MB is now rejected if it cannot be compressed below 800KiB. This is deliberate to prevent long-running unreliable transfers, but it is a user-visible restriction.
- An unknown route defaults to the conservative BLE cap. This can reject a 0.8–3MB image even when a fast link becomes available later; the user can retry after a fast secure route is active.
- The policy does not add ACK-pipelined attachment scheduling. If an 800KiB BLE image still exceeds the owner's acceptable delivery window after Batch A integration, a later controlled patch must change scheduling without changing Wire v4 framing.

## Performance and privacy

- More aggressive BLE compression can increase one-time CPU work, but it occurs in the existing detached transcoder rather than on the main thread.
- Startup signposts disclose timing categories only; they add no user content, media, credentials, or identifiers to diagnostics.

## Validation limitations

- Linux validates the pure policy only. It cannot typecheck UIKit, SwiftUI, ImageIO, CoreGraphics, or OSLog against Apple SDKs.
- The repository-wide parser currently reports seven unchanged Build64 failures; each is reproduced from the clean source baseline.
- Per owner instruction, physical-device testing is not a blocker for coding and is recorded as `NOT_RUN`.

## Rollback strategy

- Reverse-apply this patch. No migration, persisted-data conversion, protocol change, or cache invalidation is involved.
