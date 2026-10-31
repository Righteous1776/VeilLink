# External Gomoku engine — governed integration

Source: https://github.com/zv38/gomoku-engine
Pinned upstream commit: 0d8d6d960ab5d5f89a7219b8b7fe327ebbda4440
Original source path: engine.js (Git blob f10489667b41c13df5eadfb9bd957e7c4003d82a)
Copyright: 2026 workbuddy
License: MIT OR Apache-2.0 (we elect MIT; complete upstream MIT LICENSE included).

Changes to vendored engine.js:
1. Disable isForbidden(): VeilLink uses freestyle Gomoku, not Renju double-three/double-four/overline forbidden rules.
2. Restore both black & white double-three/double-four combo values in evaluation (freestyle).
3. Disable the upstream center-only response opening book when the first stone was not at (7,7).
No network access, no external binaries or pretrained weights. The Swift application uses JavaScriptCore for local evaluation.

Integration remains experimental and OFF by default until native iOS15/iOS26 physical validation and matched-strength tests. The existing GomokuBot remains the fallback, and all learning files/DB schemas are unchanged. Upstream's search strength claims are not independently verified.

Upstream is research quality with small adoption; verify full tactical suite before changing the default. Beware of JSCore initialization/memory and CPU thermal behavior; test iPhone 13 at 250ms and 1400ms as well as unsupported/legacy hardware. No source from GPL-3.0 Rapfi has been copied.
