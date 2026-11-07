# Submission Manifest

- agent_id: game-agent
- task_id: signal-dive-realtime-v1
- status: DROPPED
- base_main_sha: 97b1da6ffa0a1b3a7c61a4f725ae67c1375492a4
- created_at: 2026-10-04T11:35:00+08:00
- scope: Additive real-time 2D deep-sea exploration/search prototype with deterministic fixed-step core, sonar-as-perception mechanic, SpriteKit volumetric-style lighting/fog, sonar echoes, suspended particles, large unknown silhouettes, emotional radio beats and SwiftUI HUD.
- proposed_files: VeilLink/Core/SignalDiveGame.swift; VeilLink/UI/SignalDiveScene.swift; VeilLink/UI/SignalDiveLabView.swift; VeilLinkTests/SignalDiveGameTests.swift
- protected_surfaces: none
- dependencies: Foundation; SwiftUI; SpriteKit; CoreImage; UIKit; XCTest; no new runtime package dependency
- known_overlaps: no direct SignalDive file/symbol overlap found on current main; behavioral adjacency with staged Game Lab/render-stack proposals only
- source_prompt_summary: Continue the richer real-time 2D game line after Rainline, emphasizing deep-sea scale, sonar-driven perception and emotional atmosphere rather than old-device performance constraints.

## Baseline

This proposal is authored against exact main `97b1da6ffa0a1b3a7c61a4f725ae67c1375492a4` after re-reading repository governance and Issue #6.

## Proposal boundary

The patch adds four new files only. It does not modify existing product files, MiniGameKind, GameLobby, MiniGameViews, ArcadeGameViews, project.yml, protocol/schema, storage, identity, A9/A10 governance, workflows, version/build values, signing or release configuration.

## Extra audit files

- `ART_DIRECTION.md`
- `STORY_BEATS.md`
- `OPEN_SOURCE_INTAKE.md`
- complete proposed source under `FILES/`

## Preparation evidence

- Pure Foundation core compiled under Swift 6.2.1.
- 3,000-tick equal-state replay harness passed.
- Resource bounds held under long thrust/sonar/light inputs.
- Different seeds produced different massive-unknown sonar echo fields in a targeted harness.
- SpriteKit scene, SwiftUI lab and XCTest files passed Swift frontend parser checks.
- Full iOS semantic compile, shader compilation and visual runtime validation remain Integration Governor gates.
