# Risks

## Protected surfaces

No protected surface is modified. Any future navigation, multiplayer, persistence, protocol, release or A9/A10 integration must be separately reviewed.

## Cross-agent overlap

No direct `SignalDive*` file or symbol overlap was found on current main at preparation time.

Behavioral adjacency exists with staged real-time Game Lab submissions and render-performance policy work. This agent does not resolve shared navigation or common render-stack design. Integration Governor arbitration remains required.

## Gameplay risks

### Sonar can become either mandatory spam or irrelevant

If floodlight visibility is too good, sonar loses purpose. If sonar is too cheap, it becomes a button to press constantly.

Mitigation:
- cooldown;
- explicit power cost;
- noise increase;
- sparse floodlight range;
- playtest sonar-contact density and beacon spacing.

### Unknown echoes could feel like fake horror decoration

The massive-unknown class is intentionally ambiguous, but it must not become cheap jump-scare content.

Mitigation:
- no attack behavior in V1;
- no gore/graphic threat;
- silhouettes remain distant;
- use them primarily for scale and uncertainty.

### Battery curve

High thrust + floodlight + sonar can still create harsh resource pressure.

Mitigation: deterministic policy simulations and human playtests before product promotion. Proposal preparation already adjusted the first overly aggressive drain curve.

## Rendering risks

### Full-screen shader compatibility

SpriteKit fragment shader syntax may parse in Swift while failing on a specific device GPU/runtime.

Mitigation: iOS simulator + physical-device shader compile gate and a plain-color fog fallback if Governor integrates.

### Core Image bloom + shader + emitters

The combination is intentionally visually ambitious and can be GPU-heavy.

Mitigation: profile modern target hardware during integration. Old iPhone 7 performance is not a product-design gate per current user direction.

### Large silhouettes

Very large SKShapeNode content can overdraw.

Mitigation: keep silhouette count low and stream only nearby trench segments.

## Open-source licensing risks

No third-party code/assets are shipped by this patch.

If selected later:
- ShaderKit requires MIT notice when code is copied/vendorized.
- Kenney Fish Pack is CC0 per official source.
- Aqualand advertises CC0; provenance should still be recorded before committing assets.

## Security / privacy

No network, account identity, message content, microphone, camera, location, telemetry or model weights are used.

## Rollback

All four proposed product/test files are additive. Rollback is deletion plus removal of any separately added navigation hook.

## Validation limitation

Foundation core compiled and deterministic harnesses ran under Swift 6.2.1. SpriteKit/SwiftUI files passed parser validation only; full iOS semantic compile is still required.
