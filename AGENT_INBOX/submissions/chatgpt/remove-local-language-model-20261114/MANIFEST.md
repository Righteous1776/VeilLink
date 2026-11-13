# Model-free VeilLink — remove unused local native language model
agent_id: chatgpt
task_id: remove-local-language-model-20261114
base_main_sha: eb487a1901c0ffddfb38b80b9fb56f6d7d749ba0
source_branch: main
source_sha: eb487a1901c0ffddfb38b80b9fb56f6d7d749ba0
mode: INBOX_ONLY
status: DROPPED
scope: Remove Vertex 35M, Qwen and llama native LLM dependencies, preserve rule-based VeilTalk Lite and game A10
files:
- PATCH.diff
- DELETE_MANIFEST.txt
- GOVERNOR_APPLY.md
- FILES/LocalTextModelRuntimeFactory.swift
- FILES/AgentHomeView.swift
- FILES/AgentCoordinator.swift
- FILES/VeilTalkLiteRuntime.swift
- FILES/project.yml
- FILES/LocalLanguageModelRemovalTests.swift
- PROPOSAL.md
- TEST_PLAN.md
- RISKS.md
