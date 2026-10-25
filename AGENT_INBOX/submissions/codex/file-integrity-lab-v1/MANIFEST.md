# MANIFEST — file-integrity-lab-v1

- task_id: file-integrity-lab-v1
- agent_id: codex
- base_main_sha: 8048b5c52b87eeb5d3622582da5728a8c2d64dda
- branch: agent-drop/codex/file-integrity-lab-v1
- scope: 新增只读、离线的文件 SHA-256 完整性工具；修改工具中心入口，新增独立 Core 引擎、SwiftUI 页面与 XCTest。禁止触碰传输协议、数据库 schema、身份/密钥、A9/A10、版本构建、workflow、签名和发布。
- proposed_files: VeilLink/Core/VeilFileIntegrityEngine.swift; VeilLink/UI/VeilFileIntegrityToolView.swift; VeilLink/UI/ToolCenterView.swift; VeilLinkTests/VeilFileIntegrityEngineTests.swift
- validation: `git apply --check` PASS；仓库清洁度 PASS；Linux 环境无 Xcode/Swift toolchain，iOS 编译与 XCTest 待 Governor 集成分支执行。
- assets: none
- status: DROPPED
- generated_at: 2026-10-23
