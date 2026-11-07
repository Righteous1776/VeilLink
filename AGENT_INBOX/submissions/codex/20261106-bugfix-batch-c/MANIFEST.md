# Batch C submission manifest

- agent_id: codex (ChatGPT continuation of the codex handoff)
- task_id: 20261106-bugfix-batch-c
- status: DROPPED
- base_main_sha: ccafebab147e069fbabfff579dbf323b0d54f191
- scope: C1 initial chat bottom anchor + bottom-proximity follow; C2 invite-card gesture ownership; C3 local insertion-order SQL tie handling.
- proposed_files:
  - VeilLink/UI/ConversationViews.swift
  - VeilLink/UI/MiniGameViews.swift
  - VeilLink/Storage/DatabaseStore.swift
  - VeilLinkTests/DatabaseStoreTests.swift
- delivery: five Markdown/text files under this submission only; product source remains unchanged.
- dependency: Batch A PR #137 and Batch B PR #138 should be assessed and applied in that order by Integration Governor before Batch C.
- protected_surfaces: read-only SQLite ordering query changes, no schema or migration; no Wire v4, transport framing, X25519 pairing, M5 shadow or publication changes.
- overlap: PR #138 modifies ConversationViews; PR #129 also modifies ConversationViews; PR #130 modifies ConversationViews and MiniGameViews. Do not auto-resolve.
- asset_grant: not applicable; no assets/binaries.
- source: verified GitHub Build64 main and owner 2026-11-06 bugfix-package; source anchors checked.
- verification: exact source-anchor and hunk-count checks PASS; Apple SDK, Xcode, XCTest, and physical-device validation NOT_RUN.
- release: no version, workflow, main, Issue #6 or IPA mutation.
