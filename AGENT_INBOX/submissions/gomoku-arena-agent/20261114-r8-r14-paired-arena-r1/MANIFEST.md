# [AGENT-DROP] Gomoku R8-compatible versus R14 direct-native match harness

- agent_id: `gomoku-arena-agent`
- task_id: `20261114-r8-r14-paired-arena-r1`
- base_main_sha: `eb487a1901c0ffddfb38b80b9fb56f6d7d749ba0`
- mode: `INBOX_ONLY`; no live-lane grant; no version/build/release authority
- submission_path: `AGENT_INBOX/submissions/gomoku-arena-agent/20261114-r8-r14-paired-arena-r1/`
- dependency: R14 product integration proposal #215, development branch #217 (later #218–#220 supersede selected integration variants); require explicit Governor choice before patch application
- source baseline: released tag `v29.0-b66`; GomokuBot Swift blob `7844f40ba47a531e4233014007d7e47dda64b57d`
- source candidate: R14 development branch GomokuBot Swift blob `ccb874aa5c8b6dfe6ed314313e417e85bd20a67e`
- scope: pure XCTest source-level direct paired 15×15 native Gomoku contest, and independent Python replay/bootstrap auditor
- submitted: `MANIFEST.md`, `PROPOSAL.md`, `PATCH.diff`, `TEST_PLAN.md`, `RISKS.md`, `FILES/VeilLinkTests/GomokuR8R14PairedArenaTests.swift`, `FILES/Validation/audit_r8_r14.py`, `FILES/Validation/test_audit_r8_r14.py`
- tests_done: Swift6 source parse PASS; Swift6 XCTest API typecheck against interface stubs PASS (NOT product compile); seven Python independent auditor unit tests PASS
- tests_not_done: production target Swift/Xcode build, product XCTest, **R8 vs R14 finished games (0)**, physical iOS performance, equal-time games, Elo
- acceptance: only after Governor arbitrates latest R14 source and builds/tests its product integration branch
- status: `DROPPED` once this Inbox proposal has been committed; source proposal only, no product behavior change
