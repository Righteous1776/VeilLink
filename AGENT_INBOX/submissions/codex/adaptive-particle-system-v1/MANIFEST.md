# MANIFEST — adaptive-particle-system-v1

- task_id: adaptive-particle-system-v1
- agent_id: codex
- base_main_sha: 8048b5c52b87eeb5d3622582da5728a8c2d64dda
- branch: agent-drop/codex/adaptive-particle-system-v1
- scope: 全局原生自适应粒子层；低密度环境漂浮、全局拖拽轨迹、拖拽结束与根状态切换的分解爆发；按设备、低电量、温控、前后台和辅助功能动态预算；旧设备自动关闭，但现有上帝模式可强制高质量瞬态特效，并以独立 persistent 开关控制持续粒子。
- proposed_files: VeilLink/Core/VeilParticlePerformancePolicy.swift; VeilLink/UI/VeilAdaptiveParticleLayer.swift; VeilLink/App/VeilLinkApp.swift; VeilLinkTests/VeilParticlePerformancePolicyTests.swift
- validation: `git apply --check` PASS；`git diff --check` PASS；10 项策略 XCTest 已编写；云环境无 Swift/Xcode toolchain，iOS 编译、Core Animation/能耗和真机帧率待 Governor 集成执行。
- assets: none
- status: DROPPED
- generated_at: 2026-10-24
