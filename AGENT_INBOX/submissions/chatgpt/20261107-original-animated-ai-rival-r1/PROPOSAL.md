# Grok bot R2 — native liquid morphology and opponent reactions

This R2 upgrades the existing **PR #160** in place, replacing its rectangular robot with an independently designed liquid/organic character closer in **motion language** to the owner's referenced study.

## What was studied
- Public `blessonism/grok-icon-study` is an unofficial reconstruction using coordinated state/pose, spring response, blink, ocular gaze, shape and sequence layers.
- These **general animation principles** were analyzed. No vertex tables, extracted geometry, proprietary paths, copyrighted SVGs, third-party JS or mascot identity were transferred.

## Implemented in updated PATCH.diff
1. Rewrite `VeilOpponentAvatarView.swift` using a 32-point, smoothly stitched procedural liquid contour (quadratic path midpoints), with independent radial oscillations, breathing, transition overshoot, squash/stretch and responsive facial motion.
2. Original expressive eyes (idle/blink, thinking gaze and orbit, won crescent, lost slant, draw flat), dark gradient body and thin rim highlight. Mood still comes from actual AI state.
3. iOS-native SwiftUI `Canvas`/ `TimelineView`, iOS 15+ target; 30 FPS nominal, 15 FPS Low Power, paused while inactive or Reduce Motion. Decorative `.allowsHitTesting(false)`; no WebView or asset bundle.
4. The independent Owner Mode **Grok bot** toggle, default OFF and gated by `visualEffects`, and all nine local AI opponent entrypoints remain unchanged in the retained surrounding patch.
5. Added policy tests for animation suspension and bounded transition physics.

## Governance
- Single PR #160; not a duplicate proposed PR. At integration arbitrate GameLobbyView with #159 (solo save), #128 side selection, #141 export, #129 file importer.
- Apple Xcode, simulator, hardware performance and visual comparison have NOT been run. No source/main/IPA modifications.

## R3: generated looping GIF playback
- Exact reference-style transparent GIF generated in the session (24 frames, 110 ms each, infinite loop) in 112px and 200px versions.
- New optional native ImageIO/UIImageView GIF playback path in VeilOpponentAvatarView: if a bundled `GrokBotLoop.gif` exists, show it, loop automatically, pause on background or Reduce Motion; otherwise use the existing SwiftUI Canvas fallback. Cached decoded imagery avoids duplicate 24-frame allocations.
- Existing 9 AI game screen placements and the independent Owner Mode `Grok bot` toggle remain unchanged.
- **Binary itself NOT committed**: current Asset Drop permission explicitly excludes .gif and this agent. See GIF_ASSET_HANDOFF.md for exact bytes, SHA, path and integration instructions.
