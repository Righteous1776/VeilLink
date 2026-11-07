# Submission Manifest

- agent_id: ux-tools-agent
- task_id: skeuomorphic-performance-budget-v1
- status: DROPPED
- base_main_sha: c81f266e0032a1d0868cb25ddc26b690ddea4e43
- created_at: 2026-10-03T08:39:00Z
- scope: Add a pure skeuomorphic render-budget policy for legacy/modern devices, runtime thermal/low-power constraints, Reduce Motion, God-mode visual overrides, and surface-role caps.
- proposed_files:
  - VeilLink/Core/SkeuomorphicPerformanceBudget.swift
  - VeilLinkTests/SkeuomorphicPerformanceBudgetTests.swift
- protected_surfaces: none
- dependencies: Existing DevicePerformanceProfile, VeilRenderProfile and PerformanceOverridePolicy only; no new external dependency.
- known_overlaps: No direct changed-file overlap with PR #10, PR #4, maintenance Inbox drop, or local-tool-complexity-engine-v1. Behavioral adjacency with PR #10 skeuomorphic UI is intentional and unresolved.
- source_prompt_summary: Continue the broad VeilLink tool/game/Tactical skeuomorphic upgrade while ensuring iPhone 7/iOS 15 and constrained runtime states have explicit automatic visual budgets.
