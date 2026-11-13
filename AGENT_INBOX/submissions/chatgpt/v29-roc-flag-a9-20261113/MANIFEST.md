# V29 region-independent Republic of China flag + accurate A9 health UI
agent_id: chatgpt
task_id: v29-roc-flag-a9-20261113
source_branch: main
source_sha: eb487a1901c0ffddfb38b80b9fb56f6d7d749ba0
base_main_sha: eb487a1901c0ffddfb38b80b9fb56f6d7d749ba0
mode: INBOX_ONLY
status: DROPPED
scope: user-facing visual presentation only (no transport, storage, model or encryption edits)
proposed_files:
- VeilLink/UI/VeilInlineGlyphText.swift [NEW]
- VeilLink/UI/ConversationViews.swift
- VeilLink/UI/AgentChatView.swift
- VeilLink/UI/LingCoreTinyChatView.swift
- VeilLink/UI/SettingsView.swift
- VeilLinkTests/VeilInlineGlyphTextTests.swift [NEW]
source_patch: PATCH.diff

- VeilLink/UI/VeilComposerOptionGate.swift [NEW]
- VeilLinkTests/VeilComposerOptionGateTests.swift [NEW]
additional_scope: explicit chat composer input accessory; session-only opt-in, original Unicode send and existing encrypted image path
