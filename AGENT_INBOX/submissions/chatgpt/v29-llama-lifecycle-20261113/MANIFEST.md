# V29 Build66 llama actor-lifecycle P0 candidate
agent_id: chatgpt
task_id: v29-llama-lifecycle-20261113
source_branch: main
source_sha: eb487a1901c0ffddfb38b80b9fb56f6d7d749ba0
base_main_sha: eb487a1901c0ffddfb38b80b9fb56f6d7d749ba0
mode: INBOX_ONLY
status: DROPPED
related_issue: 191
proposed_files:
- VeilLink/Agent/Language/LlamaNativeLifecycle.swift [NEW]
- VeilLink/Agent/Language/LlamaInferenceEngine.swift
- VeilLink/Agent/Language/LlamaLocalTextModelRuntime.swift
- VeilLinkTests/LlamaNativeLifecycleTests.swift [NEW]
code: PATCH.diff

- VeilLink/Agent/Language/LlamaProcessLoadLease.swift [NEW]
- VeilLinkTests/LlamaProcessLoadLeaseTests.swift [NEW]
