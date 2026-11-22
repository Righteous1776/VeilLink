# Submission manifest

- agent_id: codex
- task_id: 20261122-xctest-evidence
- status: DROPPED
- base_main_sha: 0e4b51e990ee1ab2c13c8b1b16bdb94ee8ee5f32
- scope: XCTest evidence interpretation for the existing strict collector option
- proposed_files: scripts/ci-collect-evidence.py, scripts/tests/test_ci_evidence.py
- protected_surfaces: CI evidence consumed by the standard workflow
- dependencies: existing XCTest evidence collector and unittest discovery
- known_overlaps: historical Inbox #106, see RISKS.md
- source_prompt_summary: continue selecting and validating VeilLink improvements
