# MANIFEST — trollstore-capability-foundation-v1

- task_id: trollstore-capability-foundation-v1
- agent_id: codex
- base_main_sha: 8048b5c52b87eeb5d3622582da5728a8c2d64dda
- branch: agent-drop/codex/trollstore-capability-foundation-v1
- revision: 2
- scope: 第一阶段 TrollStore 适配底座；自动识别官方 TrollStore/TrollStore Lite 安装标记、App Store、TestFlight、普通 provisioning 与未知来源；以实际声明形成能力矩阵；设置页展示自动匹配结果和隐私安全诊断。设置首页同步重构为苹果式折叠分组，保留身份与安全首屏直达，其余按外观与数据、连接与通信、智能与性能折叠并记忆状态。增强 entitlement 只标为候选，不自动提权。附带 Wire v5 / DB v9 向后兼容设计，但本提交不修改协议、schema、签名或 entitlement。
- proposed_files: VeilLink/Core/VeilRuntimeEnvironment.swift; VeilLink/UI/VeilRuntimeCapabilityView.swift; VeilLink/UI/VeilSettingsDisclosureSection.swift; VeilLink/UI/SettingsView.swift; VeilLinkTests/VeilRuntimeEnvironmentTests.swift; VeilLinkTests/VeilSettingsDisclosureTests.swift
- validation: `git apply --check` PASS；`git diff --check` PASS；12 项 XCTest 已编写；云环境无 Swift/Xcode toolchain，iOS 编译、IPA 来源矩阵和真机探测待 Governor 集成执行。
- external_reference: opa334/TrollStore commit 88424f683b2a08f34a3f88985f790f97d84ce1df, Shared/TSUtil.h and RootHelper/main.m
- assets: none
- status: DROPPED
- generated_at: 2026-10-24
