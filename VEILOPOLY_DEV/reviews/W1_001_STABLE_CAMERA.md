# VLP-CODEX-W1-001 — stable movement framing

Baseline: W0 f3a7b12; product source 2c5b5161027edff097b27fe3323d30f6ca3e430e.
Scope: dev/veilopoly:VEILOPOLY_DEV/**. No Engine, RNG, save/wire or asset changes.

## Cause and fix

BoardScene.play(.tokenMove) explicitly scheduled a 0.83 camera scale over 0.2s,
then an unkeyed return to 1 over 0.3s. Fast-forward removed only the keyed
outbound action. This intentionally zoomed the entire board and could leave a
return action in flight after ACK. The current Owner/#168 stable-camera request
supersedes the older RENDERING_SPEC focus-zoom preference.

Remove both movement camera actions and the now unnecessary fast-forward reset.
Keep the existing centered camera/aspect-fit layout. Token hop, per-cell 0.15s,
shadow 0.10s frames, sounds, Reduce Motion and the one-shot ACK gate are unchanged.
No new timing constants or replacement rules. This is an independent small fix,
not a restoration of #164's six-file patch.

## Verification

- iOS15 ARM64 frontend parse of BoardScene and BoardMovementCameraTests
  → exit 0 → PASS (grammar only, not Apple SDK type-check).
- New guarded iOS XCTest source covers queued camera actions before the first
  frame, fixed camera after skip, final token landing, repeated skip ACK,
  Reduce Motion and missing-token ACK → Apple SDK unavailable → NOT_RUN.
- Existing portable RenderCommandAckGate tests cover one-shot and late callback
  rejection. Linux full-package run is recorded in CHECKPOINT continuation.
- iPhone 844×390 / 852×393, iPad 1180×820: normal completion, repeated moves,
  wraparound 39→0, fast-forward, Reduce Motion, taps during/after movement,
  day/night, resuming movement and background/foreground → NOT_RUN.

Risk: actual SpriteKit/SwiftUI frame stepping and visual/touch acceptance still
require Apple CI/device; source syntax and portable ACK tests cannot certify it.
Rollback: revert this isolated commit, not the baseline or any Agent's work.
NEXT_ONE_TASK: VLP-CODEX-W1-002 — phase-independent read-only asset browser.
