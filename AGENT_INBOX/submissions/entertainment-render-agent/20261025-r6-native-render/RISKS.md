# R6 risk register

1. R5 required model types are NOT in main; accepting R6 without prior R5 source integration will fail iOS compilation.
2. No Apple SDK available in local runtime; UIKit/SpriteKit Swift file compilation remains unverified, despite valid parse.
3. iPhone 7/15.8.3 real rendering quality, memory and frame pacing are unmeasured. Requested 30fps is not guaranteed actual FPS.
4. Native candidate deliberately separates input from render but existing P0 UIWindow global touch recognizers (#64/#65/#66) remain independent blockers.
5. This render layer is specific to E191; it does not silently fix existing RhythmNeonScene or other games.
6. Letterboxing preserves shapes but may leave unused margins on iPad. Device-specific HUD recomposition remains necessary.
7. Frame pacing and visual interpolation are not sample-accurate music playback. Sound/audio synchronization requires AVAudioEngine work and device profiling.
8. Dedicated project.yml file edits, GameLobby navigation, animation flags, user-data migrations, release and IPA are excluded.
