# Game lobby scrolling first, decorative effects second

## User observation
Intermittent app hitches; the game area uses nonessential “elegant” effects that can intercept upward/downward swipes.

## Source-verified diagnosis at af3d823546c288169d19cb3033a6111977d28bd7
- GameLobbyView.swift wraps the lobby in VeilStableScrollView but attaches veilSpatialPress to the hero and eight navigation/contact rows.
- VeilMotionKit.swift: VeilSpatialPressModifier uses `.simultaneousGesture(DragGesture(minimumDistance: 0))` with continuous gesture-state updates. This can compete with ScrollView pan recognition and force additional redraws during scrolling.
- GameLobbyView.swift has five staggered entrance effects. The hero also uses VeilDynamicGlow(active: true); VeilDynamicGlowBorder animates a .repeatForever angular glow when enabled.
- Full VStack eagerly lays out the lobby’s many game entries rather than a LazyVStack.

## Proposed scoped changes
1. Change game-lobby top-level VStack to LazyVStack, retaining section order and width constraints.
2. Remove five veilStaggeredEntrance modifiers from lobby sections.
3. Remove the hero’s veilSpatialPress and always-on veilDynamicGlow modifiers.
4. Remove seven single-player and one nearby-row veilSpatialPress modifiers. Preserve existing ButtonStyle, NavigationLink, sheets, destination actions and haptics.
5. Keep VeilMotionKit reusable API intact for other screens; do not globally disable legitimate motion or interaction.

## Out of scope / causality limits
The source proves a credible game-area gesture conflict and avoidable continuous decoration. It does NOT prove that every device-wide intermittent hitch originates in this view. Next profiling pass must use Instruments Animation Hitches + Time Profiler, points-of-interest around BLE packet bursts, SQLite, image decoding, A9/A10 telemetry and ECLIPSE move processing. No private message content needs logging.

## Acceptance criteria
- Vertical drag starting on any game row moves the list immediately; no row tilt or swipe swallowing.
- Taps still open the expected mini-game, real-time game, conversation and Veilopoly.
- No continuous hero glow animation or stagger re-entry on return.
- On comparable iPhone/iPad devices, scroll hitch count and p95/p99 frame latency do not regress versus the baseline.
- No persistence/transport/version changes.
