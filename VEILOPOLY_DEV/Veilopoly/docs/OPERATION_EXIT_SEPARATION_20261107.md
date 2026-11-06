# Veilopoly P4 · Operation control separated from Exit capsule (2026-11-07)

Task: VEILOPOLY-P4-CONTROL-SEPARATION-20261107
Base: `dev/veilopoly@27d6938955f4b97ed28e1358c7e9594b6ef16688`.

## Owner's UX correction

**Do not group the operation-panel toggle alongside the Exit capsule.**
Risk: daily interactions would increase accidental taps on the destructive Exit control.

## Revised layout

- Top-right: **More / Exit only**, original two-segment capsule unchanged; Exit still uses the existing confirmation dialog.
- Bottom-right (collapsed mode): tappable compact **player, phase, cash and gameplay status** chip is the ONE entry to everyday controls. Minimum 44pt touch height.
- Expanded mode: show the Astra-styled right overlay with a dedicated, 78×44pt minimum **Collapse** button at the **top-left of the drawer**, distant horizontally from the top-right Exit control.
- Expanded drawer continues to expose existing actionPanel (roll, buy, auction, bank, trade, etc.), tile inspector, players and feedback, without changing GameState.
- Default remains collapsed. Board geometry, SpriteKit 40 cells, game rules, animations, ACK, and card modal overlay are unchanged.

## Geometry/QA boundary

- On an 844×390pt landscape geometry, top Exit to bottom operation chip is vertically separated by >300pt (conservative point-center approximation).
- Expanded drawer's left collapse control is horizontally >280pt from Exit on the same phone geometry.
- Pure Swift metric tests were added for 844×390 and 568×320 viewports and minimum 44pt touch targets.
- These are design-math assertions, not physical on-device hitbox measurements.

## Verification pending

- Exact-head full Swift Package XCTest and Apple Xcode/iOS 16 SDK type-check.
- iPhone notch/safe-area and VoiceOver focus order; iPad expanded overlay and keyboard.
- Test collapsed/expanded transition, card dismissal, error/transaction controls and top-right Exit confirmation on actual devices.

## Governance

All changes restricted to `VEILOPOLY_DEV/**` on `dev/veilopoly`. No VeilLink `main`, P5, Info.plist, IPA, workflows, transport, databases, release or signing modified. Astra skins and accepted Kimi game resources retained.
