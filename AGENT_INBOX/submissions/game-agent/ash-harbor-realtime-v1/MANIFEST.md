# Submission Manifest

- agent_id: game-agent
- task_id: ash-harbor-realtime-v1
- status: DROPPED
- base_main_sha: 97b1da6ffa0a1b3a7c61a4f725ae67c1375492a4
- created_at: 2026-10-04T10:58:00+08:00
- scope: Additive real-time 2D rescue game prototype with deterministic fixed-step core, SpriteKit renderer, original water shader, emotional radio beats, and documented open-source asset/tool intake.
- proposed_files: VeilLink/Core/AshHarborGame.swift; VeilLink/UI/AshHarborScene.swift; VeilLink/UI/AshHarborLabView.swift; VeilLinkTests/AshHarborGameTests.swift
- protected_surfaces: none
- dependencies: Foundation; SwiftUI; SpriteKit; UIKit; XCTest; no new runtime package dependency in this patch
- known_overlaps: no direct AshHarbor file/symbol overlap found on current main; behavioral adjacency with existing/staged Game Lab and render-budget work only
- source_prompt_summary: Research high-quality open-source code/assets/story/level-design tooling, then use the safest pieces to build a more complex and emotional real-time 2D game proposal.

## Baseline

This proposal is authored against exact main `97b1da6ffa0a1b3a7c61a4f725ae67c1375492a4` after re-reading repository governance and Issue #6.

## Proposal boundary

The patch adds four new files only. It does not modify existing product files, MiniGameKind, GameLobby, MiniGameViews, ArcadeGameViews, project.yml, protocol/schema, storage, identity, A9/A10 governance, workflows, version/build numbers, signing or release configuration.

## Extra audit files

- `OPEN_SOURCE_INTAKE.md` records third-party candidates, license posture, adoption mode and package-size impact.
- `STORY_BEATS.md` contains original Ash Harbor narrative beats. No third-party story text is copied.

## Preparation evidence

- Pure Foundation game core compiled with Swift 6.2.1.
- 2,500-tick deterministic harness confirmed equal-state replay for equal seed/input and bounded hull/battery resources.
- SpriteKit scene, SwiftUI lab view and XCTest files passed Swift frontend parse.
- Full iOS semantic compile and runtime profiling remain Integration Governor gates.
