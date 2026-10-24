# Risks

## Protected surfaces

None are modified by this proposal.

Any future navigation wiring, protocol, persistence, project dependency, release or A9/A10 integration remains separate Governor-controlled work.

## Cross-agent overlap

No direct `Rainline*` path/symbol overlap was found on current main.

Behavioral adjacency exists with:
- staged Game Lab proposals;
- staged render-budget/skeuomorphic work;
- any future shared game launcher.

This proposal intentionally does not resolve those shared entry-point questions.

## Behavioral risks

### Repair loop may become repetitive

If every fault is “walk there and hold repair,” the game can feel mechanical.

Mitigation:
- fault severity affects repair time and power cost;
- car-specific dialogue changes emotional context;
- later iterations can add breaker rerouting, fuse matching and temporary bypass actions.

### Grid boost may dominate strategy

If boost always accelerates arrival enough to offset drain, the tradeoff disappears.

Mitigation:
- simulate policy variants before integration;
- tune boost traction benefit vs drain separately from fault rates.

## Rendering risks

### Heavy post-processing

CIBloom + dense rain + full-screen shader + multiple emitters can become GPU-heavy.

The owner explicitly removed old-device performance as a design ceiling for this task. Therefore the mitigation is not “strip the visuals,” but:
- profile modern target devices;
- fix pathological leaks/overdraw;
- retain the intended full visual stack.

### Core Image/SpriteKit semantics

Effect-node filter output can differ by OS/device.

Mitigation:
- integration-time iOS semantic compile;
- simulator + real-device visual check;
- preserve a non-filtered fallback only if correctness fails, not as the primary art direction.

## Migration / compatibility risks

None at protocol/schema level because Rainline is local-only and not registered in MiniGameKind.

## Security / privacy risks

No network, storage, microphone, camera, location, account identity, messages or telemetry.

## Rollback strategy

All four proposed files are additive. Rollback is deletion plus removal of any separately-added navigation hook.

## Validation limitation

The Foundation core compiled and passed a deterministic harness under Swift 6.2.1. Scene/view/test files passed parser validation only; full iOS semantic compilation remains required.
