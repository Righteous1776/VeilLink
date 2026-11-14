# Submission Manifest

- agent_id: codex
- task_id: 20261106-bugfix-batch-b
- status: DROPPED
- base_main_sha: ccafebab147e069fbabfff579dbf323b0d54f191
- created_at: 2026-11-06T10:40:27Z
- scope: Batch B — transport-aware image payload limits and startup-duration instrumentation.
- proposed_files:
  - VeilLink/Core/MediaTransferPolicy.swift
  - VeilLink/Media/ImageTranscoder.swift
  - VeilLink/UI/ConversationViews.swift
  - VeilLink/App/VeilLinkApp.swift
  - VeilLink/App/AppModel.swift
  - VeilLinkTests/MediaTransferPolicyTests.swift
- protected_surfaces: Wire v4's existing maximum image-size contract is preserved; image preparation, message UI, and startup instrumentation are changed.
- dependencies: Batch A should be applied first; the owner explicitly waived physical-device testing as an implementation blocker on 2026-11-06.
- known_overlaps:
  - PR #137 / Batch A is an ordered predecessor, but has no direct changed-file overlap.
  - PR #129 proposes Apple Files staging-lifecycle repairs; this patch changes the same image-import caller after staging, so both should be reconciled in one integration branch.
  - PR #64 contains an older startup-diagnostic proposal; this patch adds current Build64 signposts and must not be blindly combined with its older anchors.
- source_prompt_summary: Owner's ten real chat-use bugs, the verified 2026-11-06 bugfix package, and the later owner instruction to continue fixing without requiring physical-device testing first.
- asset_grant: not applicable; no binary resources

## Provenance and redline self-check

- Package SHA-256 verified: `3fc839004f45601600cf2caefbf13ac9a25227dbc5e44c0e81200974e5843b15`.
- Verified main base: `ccafebab147e069fbabfff579dbf323b0d54f191`; tree `6b2493d2c4297da0ad539fff68ce3ada59cebe68`.
- [x] Relay pairing semantics, including 60-second expiry, X25519, and six-digit confirmation, are unchanged.
- [x] SQLite schema and migrations are unchanged.
- [x] Wire v4 frame format and its 3MB protocol ceiling are unchanged; this is a sender-side policy limit only.
- [x] M5 shadow and production-cutover configuration are unchanged.
- [x] No version/build, workflow, release, signing, or source deletion is included.
- [x] The Inbox branch contains only this five-file submission; product changes remain inert `PATCH.diff` data.

## Current decision boundary

The owner waived physical-device testing as a prerequisite to continue coding. Xcode/simulator/device checks remain `NOT_RUN` rather than being represented as pass. Batch D items ⑥ and ⑩ remain explicitly blocked on the owner's required semantic clarification.
