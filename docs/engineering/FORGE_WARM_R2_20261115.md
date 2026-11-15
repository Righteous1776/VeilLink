# FORGE Soft / ECLIPSE Warm Orange R2 — owner design correction

## Scope
Correct visual mismatch in FORGE. This is not another theme ID or another animated dashboard.
Keep selection key `forge` and existing persistence. Base is V29.2 Build69 corrective
candidate `9a2a91bb6c53e95024c8830bb26316d524d25d8b`.

## Implemented
- Warm neutral charcoal and pearl-light palettes replace cold blue-gray industrial aluminum.
- Deep copper reference `#B03C0A` is **shadow**, not the bright foreground.
  Dark bright orange `#FF7C23`, active/base `#E66314`.
- FORGE panels and chat bubbles use continuous rounded geometry; no hard cut corners.
- Remove backdrop engineering grid and decorative strips/corner rivets; retain one
  restrained ambient radial warm accent.
- Reuse ECLIPSE robot's circle, soft charcoal and bright orange ring vocabulary
  for radio and CPU instruments; no fabricated percentages or fake progress.
- Softer static preview, rounded delivery/read/unread/route statuses.
- Compact composer status no longer places unreadable 8-point text in a 2-point rail.
- Input transparency and no new scrolling/drag gesture recognizers. Motion remains
  tied to real state, low power and Reduce Motion. No added timers.
- Other appearances, BLE protocol, chat ordering, keyboard geometry, game engine,
  database and release workflow intentionally unchanged.

## Known reference limitation
The current VeilLink repository does not contain an unambiguous component literally
called `礼物` (Gift), so its exact background RGB could not be source-verified.
Warm soft neutral graphite is used provisionally; inspect a user-provided visual
reference before claiming pixel-exact color parity.

## Verification required
- SwiftUI typecheck and iOS simulator snapshot comparison (light/dark FORGE,
  legacy Veil, instrument and Apple Soft).
- Chat bubble text contrast / unread states / composer keyboard and scrolling.
- Actual RF and CPU state transition visual acceptance. ECLIPSE original robot
  unaffected.
- Reduce Motion, low power, device font scaling and VoiceOver.
- Single consolidated exact-head CI when selecting this staged styling branch.
  Do not interrupt the earlier Build69 CI in progress for visual work alone.
