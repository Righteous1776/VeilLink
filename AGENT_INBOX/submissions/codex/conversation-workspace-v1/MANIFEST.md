# MANIFEST — conversation-workspace-v1

- task_id: conversation-workspace-v1
- agent_id: codex
- revision: 3
- base_main_sha: 8048b5c52b87eeb5d3622582da5728a8c2d64dda
- branch: agent-drop/codex/conversation-workspace-v1
- scope: 新增完全本地的会话工作台与消息锻造台，并把现有安全清空能力接到会话列表右滑和长按菜单；清空前必须二次确认，禁止破坏性全滑直接执行。整理完整聊天历史并跳转原消息；提供结构模板、表达样式、UTF-8 协议预算、分段预览和敏感信息检查，再由用户手动回填草稿。修改聊天入口与加载接线，新增两个纯逻辑引擎、两套 SwiftUI 和十九项 XCTest。禁止自动发送、修改消息协议、数据库 schema、身份/密钥、A9/A10、版本构建、workflow、签名或发布。
- proposed_files: VeilLink/Core/ConversationWorkspace.swift; VeilLink/Core/VeilMessageForge.swift; VeilLink/UI/ConversationWorkspaceView.swift; VeilLink/UI/VeilMessageForgeView.swift; VeilLink/UI/ConversationViews.swift; VeilLinkTests/ConversationWorkspaceTests.swift; VeilLinkTests/VeilMessageForgeTests.swift
- validation: `git apply --check` PASS；`git diff --check` PASS；19 项 XCTest 已编写；云环境无 Swift/Xcode toolchain，iOS 编译和 XCTest 待 Governor 集成执行。
- assets: none
- status: DROPPED
- generated_at: 2026-10-24
