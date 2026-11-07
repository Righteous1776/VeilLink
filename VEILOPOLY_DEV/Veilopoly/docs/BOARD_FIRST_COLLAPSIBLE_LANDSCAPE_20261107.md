# Veilopoly P4 · Board-first landscape with collapsible capsule (2026-11-07)

Task: VEILOPOLY-P4-BOARD-FIRST-20261107
Base branch: dev/veilopoly @ 3088e0b9bea41b763c1da6c02869497f0d55807b
Owner: landscape phone should maximize the board and collapse function controls into capsule/buttons.

## Source implementation
- Before: permanent right rail width min(max(W * .40, 285),395), HStack reduced board viewport.
- After: whole 40-tile scene aspect-fit is height-prioritized and left-aligned within safe GeometryReader bounds; no permanent sidebar width is subtracted. This preserves all 40 tiles.
- Default state is **collapsed**. Top-right a standalone 46×44pt operation toggle accompanies the original More/Exit 46×44pt capsule. Bottom-right live current-player/cash/phase status is tappable to expand.
- Expanded state overlays the right portion of the view, may temporarily obscure tiles on iPad; it never changes SpriteKit scene size/camera or the game's deterministic GameState.
- Drawer prioritizes real existing Astra actionPanel, then tile inspector, 2×2 player HUD, event/error messages. The drawer is vertically scrollable; all primary actions remain native SwiftUI Buttons/Fields.
- Native Reduce Motion disables transition animation. Card confirmation overlay remains above any capsule/drawer; skip command stays on existing board overlay.
- Existing phase handling, Astra UI skins, SpriteKit BoardScene, rules/AI, Net and Kimi incoming assets are untouched.

## Design constraints and expected geometry
- Phone 844×390 pt: usable height 382pt, max aspect-fit board ~416.2×382pt; drawer 371.36×326pt.
- iPad 1180×820 pt: usable height 812pt, board ~884.5×812pt; drawer 395×756pt.
- These are *design geometry*, not measured safe-area results from iOS or a hardware screenshot.
- Side sensor/notch safe areas and home indicator are handled by host GeometryReader. Actual landscape host orientation capability remains P5-gated.

## Validation and open gates
- Swift pure-metric XCTest cases cover board aspect, phone/iPad viewport bounds, max size vs old sidebar, drawer bounds and tiny viewports.
- UI layout source is guarded by `#if os(iOS)`; Linux SwiftPM does not compile or type-check its SwiftUI/SpriteKit branches.
- Mac Xcode iOS 16+ compile + 844×390, 852×393, iPad landscape visual/touch/VoiceOver/keyboard tests required.
- Verify expanded drawer on iPad never traps actions and collapsed phase-specific actions are discoverable; run card modal and Reduce Motion/ACK regressions.
- P5 host Info.plist, VeilLink game hall, IPA, signing, workflows, version and main remain OUT OF SCOPE.
