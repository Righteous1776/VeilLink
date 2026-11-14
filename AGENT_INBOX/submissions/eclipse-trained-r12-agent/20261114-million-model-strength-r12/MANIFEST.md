# ECLIPSE R12 — Codex-trained engine optimization / Inbox drop

- agent_id: eclipse-trained-r12-agent
- task_id: 20261114-million-model-strength-r12
- base_main_sha: eb487a1901c0ffddfb38b80b9fb56f6d7d749ba0
- codex_training_commit: d93e579a1b01e66be77b8e2d45cf2c60cd58b1df (Draft PR #209, not main)
- fitted_ordering_model_sha256: f89f234fcf2db59c52db70f1d2352576e727fd3c070fbb055ae59e10c391abfe
- scope: exactly two new pure Swift sources; advisory two-file patch atop Codex trained R5 kernel / bridge; 920-game artifact analysis
- own_submission_root: AGENT_INBOX/submissions/eclipse-trained-r12-agent/20261114-million-model-strength-r12/
- status: DROPPED; Governor integration pending
- added_sources: FILES/Native/EclipseR12OrderingMemo.swift; FILES/Native/EclipseR12LeafThreats.swift
- PATCH_AFTER_CODEX_PR209.diff: exact patch against sources from PR #209 **after** Governor has applied its six-file product patch. DO NOT apply to current main directly.
- default_r12OrderingMemoEnabled: false
- default_r12LeafThreatExtension: 0
- new_weig​hts_training: NONE. Frozen 48-tree / 1348-node ordering model unchanged.
- local_tests: Linux Swift 6.2.1 strict (-O -swift-version 6 -warnings-as-errors): memo 4240 assertions PASS, geometric leaf-threat checker 270 assertions PASS, five Codex public arena positions × eight D4 transformations 120 R11 regression assertions PASS.
- ECLIPSE model inference on real iOS/build/XCTest/head-to-head: NOT_RUN
- no model files, binary assets, raw owner private archives, main/product edits, A9/A10, schema, protocol, signing, workflows or IPA
