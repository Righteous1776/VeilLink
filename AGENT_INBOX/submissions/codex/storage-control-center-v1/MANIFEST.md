# MANIFEST — storage-control-center-v1

- task_id: storage-control-center-v1
- agent_id: codex
- base_main_sha: 8048b5c52b87eeb5d3622582da5728a8c2d64dda
- branch: agent-drop/codex/storage-control-center-v1
- scope: 新增本地存储管理中心、白名单清理引擎、空间/大文件雷达、缓存清理入口与安全测试；不修改数据库 schema、身份/密钥、消息/传输协议、A9/A10 治理、版本构建、workflow、签名或发布。
- proposed_files: VeilLink/Storage/VeilStorageMaintenance.swift; VeilLink/UI/StorageManagementView.swift; VeilLink/App/AppModel.swift; VeilLink/UI/SettingsView.swift; VeilLinkTests/VeilStorageMaintenanceTests.swift
- validation: `git apply --check` PASS；`git diff --check` PASS；环境无 Swift/Xcode toolchain，iOS 编译和 XCTest 待 Integration Governor 执行。
- assets: none
- status: DROPPED
- generated_at: 2026-10-23
