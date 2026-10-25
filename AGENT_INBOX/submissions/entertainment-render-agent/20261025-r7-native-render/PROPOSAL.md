# R7 native rendering optimization

Full local artifact updates the SpriteKit R6 scene and its SwiftUI host and is **not yet installed in VeilLink**.

Verified R7 improvements:
1. Cache 16 procedural notes per district/seed; avoid per-frame chart regeneration.
2. Hide running notes when their host snapshot is stale beyond 280 ms; paused notes freeze on purpose.
3. New bounded 240-observation update callback interval telemetry; never treat it as GPU-frame evidence.
4. Local R7 scene: fixed 390×600 logical canvas, aspectFit, only 5 visible note nodes, 12Hz SwiftUI HUD instead of 20Hz.
5. iOS fixed bottom 56pt lane controls outside ScrollView, avoiding scroll interception.
6. Swift XCTest conditionally imports VeilMegaEngines (Linux) or VeilLink (Apple).

The GitHub patch is for only four independent NEW filenames, unlike the local complete 13-file patch in ZIP. Governor must integrate R5+R6 prerequisites and carefully select the R7 replacement scene/UI when Xcode is available. P0 touch and identity bugfixes #64–#66 remain prioritized. Never claim installed-game state.
