# P2 camera gesture implementation contract (separate review gate)

Status: DESIGN_ONLY / NOT_IMPLEMENTED. P0/P1 candidate is not iOS-compiled yet. P2 must not be merged until preceding P0 validation is complete.

## Constraint
Use only UI / BoardScene and presentation boundary. Never edit Engine, AI, Net, RenderCommandAckGate, signing, canonical Astra assets or room/session data. Preserve existing focus position (512,470) and scale=1 when idle.

## Input state machine
- IDLE: a stationary one-finger end event can inspect a tile. Tap during animation still goes to the existing fast-forward command.
- PAN: begin only after a one-finger displacement threshold in the SpriteKit viewport (>= 8pt); suppress tap on release. Cap camera translation to ±80pt from base; release animates camera back to base over 0.3s.
- PINCH: exactly two fingers; measure their midpoint and separation in stable SKView (view-coordinate) space; clamp the visual magnification to 0.9...1.6. Maintain scene-space point under the midpoint with a camera transform; suppress every finger-end tap. Release returns scale and position to base in 0.3s.
- CANCEL: touch cancellation, app inactive/background, a render command starting, or decision panel appearing must zero pan/pinch state and return focus without triggering onBoardTap.
- GATE: disable panning/pinching while any animation is playing, card gate displayed, decision overlay visible, or app backgrounded. Do not let camera recognizers consume/advance RenderCommandAckGate.
- Prefer an explicit onSceneTouch state machine over layering competing SwiftUI highPriorityGesture on SpriteView; use SKView midpoint conversions to avoid centroid drift as camera scale changes.

## Device / UX acceptance
- 1 finger swipe in blank center; short stationary tap still clears selection; repeated tile tap toggles.
- 2-finger zoom at all four board quadrants preserves midpoint anchor; clamp 0.9x/1.6x; pan ±80; settle 0.3s.
- Pinch to single finger transition must not produce an accidental tap; drag never causes token skip.
- Reduce Motion: instant camera reset to base; no 0.3s spring if accessibilityReduceMotion is true.
- iPhone 7 iOS15.8.3; iPhone SE2 iOS15.6.1; iPhone 13 iOS26; iPad in landscape; panel overlay open/closed; large accessibility text.
- Existing BoardMovementCameraTests must still pass for no-gesture and animation timelines. Add dedicated simulated touch-state tests; then actual-device verification.
