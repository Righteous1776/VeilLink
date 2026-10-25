# Test Plan

## Static checks

- Apply PATCH.diff against exact base_main_sha.
- Confirm only four declared new files are added.
- Strict-concurrency compile scan.
- Confirm SpriteKit/UIKit imports resolve on the iOS 15 target.
- Standard repository preflight after Governor application.

## Unit tests

1. Identical seed + identical 1200-step input stream produces exactly equal state.
2. Hazard generation for a given seed/segment is stable.
3. Input vertical value is clamped to -1...1.
4. Hull, beacon and shield remain within 0...100 under long simulation.
5. Shielded run preserves more beacon energy than equivalent unshielded run over the same early storm interval.
6. First story beat appears after crossing its progress threshold.
7. A finished state does not mutate on subsequent step calls.
8. Different seeds produce a different hazard field for a representative segment corpus.

## Scene / integration tests

- SpriteView presents scene without crash.
- didChangeSize safely rebuilds rain/fog/backdrop.
- repeated restart removes stale transient nodes and resets deterministic state.
- hazard node streaming remains bounded to nearby segments.
- impact event triggers finite camera shake / flash only.
- story callback/HUD update remains on the main actor.
- held shield and drag steering can be used simultaneously.
- scene continues after transient frame hitch using bounded accumulator catch-up.

## Rendering checks

Full tier:
- visible three-layer parallax separation;
- rain emitter density;
- fog movement;
- beacon additive glow;
- low-energy spark activity;
- shield halo;
- lightning flash;
- dawn warming near destination.

Constrained tier:
- lower rain birth rate;
- fewer fog nodes;
- reduced transient particle counts;
- reduced camera-shake amplitude;
- no gameplay/state changes relative to full tier.

## Negative / failure cases

- extreme sustained steering;
- floor/ceiling collision;
- shield depleted while held;
- beacon reaches zero;
- hull reaches zero;
- very low frame-rate update jump;
- restart after each terminal outcome;
- Reduce Motion enabled;
- Low Power Mode / constrained render tier.

## Regression invariants

- MiniGameKind unchanged.
- Existing ArcadeGames and ArcadeGameViews unchanged.
- No wire/protocol/replay/persistence change.
- No workflow/version/build/release/signing change.
- No A9/A10 governance mutation.

## Device / OS coverage

- iOS 15 minimum deployment.
- iPhone 7-class constrained-tier real device.
- current iPhone portrait.
- iPad aspect-ratio smoke test.
- Reduce Motion.
- Low Power Mode.
- Dynamic Type/VoiceOver for SwiftUI HUD.
- target full-tier 60 fps on modern devices; constrained tier should prefer stable frame pacing over particle density.
