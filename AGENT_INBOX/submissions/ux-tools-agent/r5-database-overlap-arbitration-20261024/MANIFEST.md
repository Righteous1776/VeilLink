# MANIFEST — R5 database overlap arbitration

- agent_id: ux-tools-agent
- task_id: r5-database-overlap-arbitration-20261024
- base_main_sha: 8048b5c52b87eeb5d3622582da5728a8c2d64dda
- status: DROPPED
- scope: Governance-only adjudication proposal for PR #53 vs PR #56 schema overlap; strict R1–R5 dry-run results; proposed SQLite integration preflight.
- submission_branch: agent-drop/ux-tools-agent/r5-database-overlap-arbitration-20261024
- submission_path: AGENT_INBOX/submissions/ux-tools-agent/r5-database-overlap-arbitration-20261024/
- patch_base: exact main 8048b5c52b87eeb5d3622582da5728a8c2d64dda
- proposed_files:
  - scripts/verify-r5-sqlite-contract.py (additive integration-time check only)
- upstream_sources:
  - PR #53 AGENT_INBOX/submissions/codex/trollstore-capability-foundation-v1/COMPATIBILITY_PLAN.md
  - PR #56 AGENT_INBOX/submissions/veillink-protocol-db/protocol-v4-compat-db-v9-20261024/PATCH.diff
  - PR #56 PATCH_STAGE2.diff, PATCH_STAGE3.diff, PATCH_STAGE4.diff, PATCH_STAGE5.diff
- authority: INBOX_ONLY. No LIVE-LANE-GRANT found in latest main governance or Issue #6 for this lane. No direct product edits, integration branch write, XCTest dispatch, merge or IPA release.
- evidence: Five strict hunk/context in-memory sequential patch applications on exact main PASS. Synthetic SQLite v8-shape→v9→v10 repeat migration, legacy row preservation, FK/cascade/integrity PASS; not native app migration or XCTest.
- overlaps: Protected DatabaseStore.swift, SessionCoordinator.swift and WireCodec.swift are owned by PR #56 proposed implementation; PR #53 competing v9 concept is a design document, not a DB source patch. Governor arbitration REQUIRED.
