# Proposal — release-publish opt-in gate + CI audit

## Goal
Prevent an ordinary main push or a generic unsigned-IPA workflow dispatch from implicitly becoming a public GitHub Release, while preserving product build + evidence collection.

## Verified current behavior
Current `.github/workflows/core-release.yml` runs on main pushes involving `project.yml` or `docs/RELEASE_*_BUILD_*.md`, and on `workflow_dispatch` / `workflow_call`. Its `Publish versioned GitHub Release` step permits a push on main or a `workflow_dispatch` event; it does not require an independent explicit publication input or approval environment. The reusable workflow is called by `unsigned-ipa.yml` and `dual-platform-release.yml`.

Current main `403b3dc474746d3925ad52fa4169225905bac7fc` has already produced `v27.0-b62` on 2026-10-30; this evidence confirms the path is operational, not that this specific release lacked owner approval. Release file is an unsigned IPA, not App Store signed.

## Proposed behavior
The patch changes only the protected `core-release.yml`:
- direct `workflow_dispatch` accepts a new explicit, default-false `publish_release` boolean;
- `workflow_call` declares the same input as optional/default-false;
- public publication requires `github.ref == refs/heads/main` AND `inputs.publish_release == true`.
- push-triggered builds keep producing unsigned IPA artifacts/evidence but cannot publish a GitHub Release.
- existing callers that do not explicitly pass `publish_release` remain packaging-only.

**An opt-in boolean alone is not a complete Owner-identity approval system.** Governor must separately determine whether a protected GitHub environment with required reviewers is needed, and should read real repo branch protections (API returned 403 for protection; ruleset list was empty). The patch must never be applied to product tree directly by this lane.

## Other exact-source CI omissions (audit only; NOT fixed by this patch)
1. `scripts/ci-test.sh` selects first available iPhone simulator, no required iOS 15 runtime; `project.yml` deployment target 15.0 is not runtime proof.
2. `project.yml` defines unit tests but no separate UI tests target; physical signing, touch, BLE reconnection and Files provider transitions remain unautomated here.
3. `project.yml` excludes five local AI/MaleCNS files from standard test target. Standard test suite passing does not certify heavy AI flows.
4. CI runs Debug simulator build/tests. Release iPhoneOS compilation/package checks occur only in release workflows; PR-level release parity is not a default gate.
5. XcodeGen is installed with unpinned `brew install xcodegen`; ZIPFoundation is `from: 0.9.19` rather than exact. Reproducibility/lockfile should be audited.
6. `scripts/ci-collect-evidence.py` captures compiler diagnostics but does not parse XCTest assertion failures into structured test summaries.
7. PR #100 (exact head `ced1cd0e`) iOS CI #41110884224 passed 766 XCTest cases but compiler warned `VeilMonogatariGameView.swift:174` about a WKNavigationDelegate optional method type mismatch; that method enforces local-only navigation. Confirm at runtime whether policy callback is invoked and remote/file external navigation is denied; **do not infer either vulnerability or safety from a passing build**.
8. Same PR #100 log includes main-actor protocol conformance warnings for SpriteKit contact delegate and AVAudioPlayer delegate, explicitly flagged as errors under Swift 6 language mode.
9. `AGENT_INBOX/**` path ignore means Agent Inbox Gate PASS attests structure and policy, not Apple compilation of patch payload.
10. Branch protection endpoint returned 403; absence of listed repository rulesets alone cannot prove a lack of branch protection. Governor should verify required status checks using authorized control-plane access.

## User-visible impact
Normal CI/IPA artifact path remains; only publication is opt-in. No production feature/DB/protocol code modified.

## Alternatives
- Remove release publishing entirely: strongest hold but prevents deliberately authorized releases; defer to Owner.
- Add protected environment reviewers: recommended as a follow-up explicit governance layer, requires repository settings and review of permissions.
- Allow push automation unchanged: rejected for weak release authorization isolation.

## Acceptance criteria
1. Governor reviews exact main baseline, reusable-workflow callers, and authorization scope.
2. Proposed workflow YAML passes parser/actionlint and PR static validation.
3. Push main with release docs does not publish; manual dispatch with publish=false does not publish; non-main publish=true denied; main manual publish=true subject to Owner approval can publish only when tests/package checks pass and tag does not exist.
4. Existing `unsigned-ipa.yml` / dual-platform callers retain packaging-only behavior with default input false.
5. Full Apple CI/real-device P0 acceptance remains required before actual release.
