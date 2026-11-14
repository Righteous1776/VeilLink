# Verification plan (NOT_RUN; requires Apple build/test environment)

1. Static patch audit: only `VeilLink/UI/GameLobbyView.swift` changes. Check all navigation destinations, game entries, and sheet bindings against base af3d823546c288169d19cb3033a6111977d28bd7.
2. Apply with `git apply --check PATCH.diff` to exact base; confirm no conflicts before any product-tree integration.
3. Run XcodeGen project generation and both simulator Debug and iPhoneOS Release builds; run existing unit tests and VeilLinkUITests. Must pass CI before integration.
4. UI swipe test on iPhone 13/iOS 26: swipe up/down beginning over the hero, single-player rows, contact rows, and real-time game rows; verify expected vertical displacement in one gesture. Repeat during BLE receive and while switching tabs.
5. Tap test: game destinations and nearby match conversation remain reachable with single taps.
6. Motion test: no ongoing halo rotation in idle Game Lobby, and no delayed stagger entrance when returning from a game. Other screens' legitimate animations should be unaffected.
7. Performance test: Instruments Animation Hitches + Time Profiler, 3 runs each of 60-second idle, 60-second repetitive scroll, and BLE traffic; compare main-thread blocking, frame timing and allocations vs af3d823546c288169d19cb3033a6111977d28bd7. Test under normal/low-power/thermal-constrained states.
8. Device-wide intermittent hitch triage remains unresolved until traces identify hotspots. Diagnose chat, games, AI and image import separately; DO NOT claim full freeze remediation solely from this patch.

No tests or device runs were executed by this Inbox submission.
