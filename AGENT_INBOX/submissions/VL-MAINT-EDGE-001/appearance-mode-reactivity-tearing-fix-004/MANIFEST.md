# Submission Manifest

- agent_id: VL-MAINT-EDGE-001
- task_id: appearance-mode-reactivity-tearing-fix-004
- status: DROPPED
- base_main_sha: 8048b5c52b87eeb5d3622582da5728a8c2d64dda
- created_at: 2026-10-24T09:22+08:00
- scope: repair day/night appearance tearing by making core visual surfaces directly observe VeilAppearanceController; proposal only, no product-tree mutation
- proposed_files: VeilLink/Core/AppTheme.swift; VeilLink/Core/SkeuomorphicComponents.swift; VeilLink/Core/VeilMotionKit.swift; VeilLink/Core/VeilAppleMaterialEngine.swift; VeilLinkTests/GlobalAppearanceModeTests.swift
- protected_surfaces: none; UI/theme rendering and tests only; no protocol, schema, identity, key management, A9/A10 governance, transport, storage, workflows, release/signing, or version/build changes
- dependencies: existing VeilAppearanceController ObservableObject publication; existing WindowGroup preferredColorScheme behavior; SwiftUI ObservedObject invalidation on iOS 15+; Apple Soft material brightness must use the same resolved appearance as the central palette
- known_overlaps: no direct overlap found with any currently open PR (#9, #10, #18-#21, #25-#35, #49-#54) across the four proposed files at preparation time
- source_prompt_summary: owner supplied a real screen recording showing broken day/night switching and explicitly assigned this maintenance lane to fix it and submit the repair to Agent Inbox
