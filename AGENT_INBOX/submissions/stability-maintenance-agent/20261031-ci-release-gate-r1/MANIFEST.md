# Submission Manifest

- agent_id: stability-maintenance-agent
- task_id: 20261031-ci-release-gate-r1
- status: DROPPED
- base_main_sha: 403b3dc474746d3925ad52fa4169225905bac7fc
- created_at: 2026-10-31
- scope: Core release authorization hardening candidate, plus exact-head CI coverage audit
- proposed_files: .github/workflows/core-release.yml
- protected_surfaces: .github/workflows/** and release-publication control, Governor-only application
- dependencies: Owner publication authorization and Governor integration review; no existing release/tag mutation
- known_overlaps: Existing core-release.yml, dual-platform-release.yml and unsigned-ipa.yml reusable workflow callers; compare all active product PRs before integration
- source_prompt_summary: Owner requested continuing stability maintenance and checking omitted CI problems.
- asset_grant: none
