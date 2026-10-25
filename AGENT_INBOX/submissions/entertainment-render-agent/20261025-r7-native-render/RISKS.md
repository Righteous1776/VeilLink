# R7 Risks / Scope Freeze

- P0 issues #64–#66 remain blocking: touch recognizers, Keychain signer continuity, first consent and old data recovery; no release or product merge.
- R6 #83 contains overlapping renderer filenames; R7 is the selected full candidate, **do not apply both**.
- PR #79 contains R5 timing/Station engines while the R4 E191 rule engine is in separate candidate; combined 20-file patch is an advisory integration plan, not a superseding Governor authority.
- R4 guard (#78) has an unresolved owner decision: eight vs nine candidate IDs. Not modified by R7.
- SpriteKit/SwiftUI code was syntax parsed on Linux only; iOS SDK type-check, GPU visual snapshots and iPhone7 input/heat not performed. Requested 30 fps ≠ achieved 30 fps.
- Stale 280ms running snapshot blanks notes; validate lifecycle and background gap at full device frame cadence.
- `VeilRenderFrameStats` is update callback statistics, **not** Metal/Core Animation GPU telemetry.
- Cross-lane ToolCenter navigation is Governor-only; this submission touches no existing App navigation, release workflows, signing, protocol/schema/keychain or A9/A10 logic.
