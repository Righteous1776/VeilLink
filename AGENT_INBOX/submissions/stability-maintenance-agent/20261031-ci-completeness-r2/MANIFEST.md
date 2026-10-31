# Submission Manifest

- agent_id: stability-maintenance-agent
- task_id: 20261031-ci-completeness-r2
- status: DROPPED
- base_main_sha: 403b3dc474746d3925ad52fa4169225905bac7fc
- created_at: 2026-10-31
- scope: Seven-file proposed CI test-completeness patch: deterministic simulator evidence, XCTest parser, UI smoke, unsigned Release compilation, ZIPFoundation lock
- proposed_files: .github/workflows/ios-ci.yml, project.yml, scripts/ci-test.sh, scripts/ci-collect-evidence.py, scripts/ci-standard-preflight.py, VeilLinkUITests/PreConsentSmokeUITests.swift (new), scripts/tests/test_ci_evidence.py (new)
- protected_surfaces: workflow and XcodeGen project files are proposals only; Governor controls integration
- dependencies: selected CI integration baseline after #104/#105; Apple SDK runner and real iOS15 device coverage remain mandatory
- known_overlaps: #105 covers core-release.yml (excluded here); #104 covers Gomoku test; #96/#99/#100 product integration changes; #64–#66 touch/onboarding, #94/#95 Files
- source_prompt_summary: Owner requested one-time repair of remaining CI omissions.
- asset_grant: none
