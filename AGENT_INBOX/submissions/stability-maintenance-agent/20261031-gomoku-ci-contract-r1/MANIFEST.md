# Submission Manifest

- agent_id: stability-maintenance-agent
- task_id: 20261031-gomoku-ci-contract-r1
- status: DROPPED
- base_main_sha: 403b3dc474746d3925ad52fa4169225905bac7fc
- created_at: 2026-10-31
- scope: CI/XCTest regression contract correction for default local Gomoku baseline decision display; test-only candidate
- proposed_files: VeilLinkTests/AgentControlAndLocalGameTests.swift
- protected_surfaces: None. No product code, app state, storage, identity, protocol, build/version, signing or workflows.
- dependencies: Integration Governor PR #96; stacked PR #99 depends on #96; exact PR-head Apple CI required
- known_overlaps: The test file is exercised by PR #96 and stacked #99, but this submission does not edit those branches. Governor must select the patch for the intended integration branch and reconcile all candidate tests.
- source_prompt_summary: Owner assigned stability maintenance and bug triage. Two exact-head iOS CI runs fail solely on stale Gomoku decision label assertion.
- asset_grant: none
