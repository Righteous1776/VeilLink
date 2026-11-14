# [AGENT-DROP] ECLIPSE R12 / Codex-trained Search Horizon Repair

- agent_id: eclipse-horizon-agent
- task_id: 20261114-trained-leaf-extension-r12
- mode/status: INBOX_ONLY / DROPPED / integration pending
- base_main_sha: eb487a1901c0ffddfb38b80b9fb56f6d7d749ba0 (V29)
- overlay_source: Codex #209 / commit d93e579a1b01e66be77b8e2d45cf2c60cd58b1df (trained native kernel, not main)
- trained_model_sha256: f89f234fcf2db59c52db70f1d2352576e727fd3c070fbb055ae59e10c391abfe (UNCHANGED)
- complete_new_files: FILES/EclipseHorizonQuiescenceR12.swift; FILES/VeilLinkTests/EclipseHorizonR12Tests.swift
- complete_proposed_existing_file: FILES/Native/VeilGomokuUnifiedSearch_R12_Overlay.swift (review-only copy of Codex #209 trained kernel with opt-in leaf upgrade)
- exact_advisory_patch: PATCH.diff (3 sections, 4 hunks; applies AFTER the Codex #209 product patch, NOT directly to V29 main)
- frozen_920_arena_audit: EVIDENCE/ARENA_920_LEAF_AUDIT.json
- tactical_replay_fixtures: FILES/TESTS/codex_920_r12_cases.json (192 from 920 generated Codex evaluation matches)
- tests: Linux Swift 6.2.1 strict optimized 1,607 assertions PASS; 192 fixture labels independently brute-verified; original Codex overlay preimage 2/2 PASS
- not_run: full trained iOS kernel build, app XCTest, device, changed-vs-frozen paired full games; no Elo/superhuman or 6× chess-strength claim
- no product/main edits, A9/A10 governance, protocol, schema, workflows, releases, binary weights or IPA
