# MANIFEST — lifecycle-stability-gate-v1

- task_id: lifecycle-stability-gate-v1
- agent_id: codex
- base_main_sha: 8048b5c52b87eeb5d3622582da5728a8c2d64dda
- branch: agent-drop/codex/lifecycle-stability-gate-v1
- scope: 对 SwiftUI/UIKit 生命周期事件做单航班去重，统一首次启动、前后台转换、压力测试活跃态和内存警告回收；新增纯状态机与 XCTest。不得改变传输协议、数据库 schema、身份/密钥、A9/A10 治理、版本构建、workflow、签名或发布。
- proposed_files: VeilLink/Core/VeilLifecycleStabilityGate.swift; VeilLink/App/VeilAppLifecycleCoordinator.swift; VeilLink/App/VeilLinkApp.swift; VeilLinkTests/VeilLifecycleStabilityGateTests.swift
- validation: `git apply --check` PASS；`git diff --check` PASS；当前 Linux 环境无 Swift/Xcode toolchain，iOS 编译和 XCTest 待 Governor 集成分支执行。
- assets: none
- status: DROPPED
- generated_at: 2026-10-24
