# Submission Manifest

- agent_id: game-agent
- task_id: signal-dive-content-assets-v2
- status: DROPPED
- base_main_sha: 41ebd5728e72683fd035c48e1fe5ea194f78a086
- asset_grant: VEILLINK-ASSET-GAME-001
- supersedes: signal-dive-realtime-v1 / Draft PR #29
- scope: Signal Dive V2 biological content, accessibility/compatibility and direct CC0 fish assets.
- proposed_files: VeilLink/Core/SignalDiveGame.swift; VeilLink/UI/SignalDiveScene.swift; VeilLink/UI/SignalDiveLabView.swift; VeilLinkTests/SignalDiveGameTests.swift
- assets: ASSETS/signal_dive_kenney_fish_1.png; ASSETS/signal_dive_kenney_fish_2.png; ASSETS/signal_dive_kenney_fish_3.png
- protected_surfaces: none
- known_overlaps: shared future Game Lab navigation/render policy remains Governor-owned

## V2 delta

- deterministic biological sonar contact class;
- biological schools use the same contact data as sonar;
- three direct CC0 Kenney Fish Pack PNG textures;
- procedural fish fallback when assets are absent;
- Reduce Motion lowers particle load and disables camera shake;
- existing seeded massive-unknown/sonar spatial consistency retained.
