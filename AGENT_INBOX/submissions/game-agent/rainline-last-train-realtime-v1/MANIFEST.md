# Submission Manifest

- agent_id: game-agent
- task_id: rainline-last-train-realtime-v1
- status: DROPPED
- base_main_sha: 97b1da6ffa0a1b3a7c61a4f725ae67c1375492a4
- created_at: 2026-10-04T11:20:00+08:00
- scope: Additive real-time 2D side-view train repair game with deterministic fixed-step core, SpriteKit scene graph, bloom, neon city parallax, glass-rain shader, carriage power propagation, emotional story beats and SwiftUI HUD.
- proposed_files: VeilLink/Core/RainlineLastTrainGame.swift; VeilLink/UI/RainlineLastTrainScene.swift; VeilLink/UI/RainlineLastTrainLabView.swift; VeilLinkTests/RainlineLastTrainGameTests.swift
- protected_surfaces: none
- dependencies: Foundation; SwiftUI; SpriteKit; CoreImage; UIKit; XCTest; no new runtime package dependency
- known_overlaps: no direct Rainline file/symbol overlap found on current main; behavioral adjacency with staged Game Lab and render-stack proposals only
- source_prompt_summary: Continue the real-time 2D game line after Ash Harbor, prioritize visual complexity and emotion, and do not treat iPhone 7 / iOS 15 performance as the design ceiling.

## Baseline

This proposal is authored against exact current main `97b1da6ffa0a1b3a7c61a4f725ae67c1375492a4` after re-reading AGENTS.md, Agent Inbox governance files and Issue #6.

## Proposal boundary

The patch adds four new files only. It does not modify MiniGameKind, GameLobbyView, MiniGameViews, ArcadeGameViews, project.yml, protocols, persistence, identity, A9/A10 governance, workflows, version/build values, signing or release configuration.

## Preparation evidence

- Foundation core compiled with Swift 6.2.1.
- 7,200-tick deterministic harness confirmed equal-state replay for equal seed/input and bounded train power/traction resources.
- Scene, SwiftUI lab and XCTest files passed Swift frontend parse.
- Full iOS semantic compilation and runtime visual validation remain Integration Governor gates.
