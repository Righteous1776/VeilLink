# MANIFEST — conversation-workspace-v1

- task_id: conversation-workspace-v1
- agent_id: codex
- base_main_sha: 8048b5c52b87eeb5d3622582da5728a8c2d64dda
- branch: agent-drop/codex/conversation-workspace-v1
- scope: 新增完全本地的会话工作台，将完整聊天历史整理为行动项、待回答问题、链接和附件索引，并可跳转原消息；修改聊天入口与加载接线，新增纯分析引擎和 XCTest。禁止修改消息协议、数据库 schema、身份/密钥、A9/A10、版本构建、workflow、签名或发布。
- proposed_files: VeilLink/Core/ConversationWorkspace.swift; VeilLink/UI/ConversationWorkspaceView.swift; VeilLink/UI/ConversationViews.swift; VeilLinkTests/ConversationWorkspaceTests.swift
- validation: `git apply --check` PASS；`git diff --check` PASS；云环境无 Swift/Xcode toolchain，iOS 编译和 XCTest 待 Governor 集成执行。
- assets: none
- status: DROPPED
- generated_at: 2026-10-24
