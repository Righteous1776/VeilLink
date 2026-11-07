# VEILOPOLY-DEV-001 — 独立研发域治理章程

**Issued from:** repository Owner's explicit request (2026-11-06)  
**Authority chain:** Repository Owner → Integration Governor `VEILLINK-IG-001` → Veilopoly Development Lane Agents  
**Repository:** `Righteous1776/VeilLink`  
**Dedicated branch:** `dev/veilopoly`  
**Authorized path:** `VEILOPOLY_DEV/**` on the dedicated branch ONLY

## 1. 研发权限：与 Inbox 平行，不是 Inbox 下属

本权限仅表示 **独立研发通道**：Veilopoly Agent 可在被授权分支的 `VEILOPOLY_DEV/**` 内直接增删改游戏代码、测试、文档与合规素材，做本域的重构和回归验证，无需每次将开发产物包装为 `AGENT_INBOX/submissions/` 提案。

`AGENT_INBOX/` 与 `VEILOPOLY_DEV/` 同为独立研发工作区，**在变更进入产品 `main` 的审核门禁上平等**。这不是给予 Veilopoly 超越 Inbox / 其他 Agent 的全仓管辖权。

## 2. Live lane — 明确范围授权

`[INTEGRATION-GOVERNOR][LIVE-LANE-GRANT][VEILOPOLY-DEV-001]`

- Lane: `veilopoly-dev`
- Branch: `dev/veilopoly`
- Writable paths: `VEILOPOLY_DEV/**` ONLY
- Purpose: P1–P4 规则引擎、AI、单机、渲染、测试，以及 P3 接口级传输抽象
- Expiration: P4 iOS 真机/模拟器验收并完成集成评审；或 Owner / Integration Governor 明确撤销；或需要开始 P5，三者先到为准
- Validation: Swift Package build + XCTest；确定性重放；500-seed AI bounded stress test；iOS 16 SDK 构建；SpriteKit/SwiftUI、触控与动画 ack 实测；合规扫描；和最新 main 比较冲突
- Allowed reviews: 私有研发评审、开发分支 PR（仅面向开发分支，非 main）
- Not granted: 修改或合并 main、生产源码、跨域路径、release、IPA、签名、GitHub Actions 工作流

## 3. 绝对保护边界

未经 Owner 和 Integration Governor 的额外明确授权，不得修改：

- `main`，其他 Agent 分支及 `AGENT_INBOX/**`；
- VeilLink 的 BLE/LAN/互联网传输实现、`Protocol 4`、`VLGM1`；
- `SQLite Schema V8` 或迁移、身份与密钥管理；
- `.github/workflows/**`，版本号/build 值、release/tag、签名与 IPA；
- A9/A10/A13 治理、应用主体的游戏大厅入口与其他游戏；
- 回滚恢复分支、其他 Agent 的提交、独立维护线。

不强推、不强制重置、不自行合并 `main`，不擅自派发构建、发布或签名工作流。

## 4. 提交纪律

每项变更必须带有：任务编号、基线 SHA、涉及文件、测试结果、已知缺陷、与其他 lane 的重叠情况。出现跨域触碰、重复实现、规则歧义或 CI 阻塞时，记录并交 Issue #6；不能通过静默覆盖来解决。

**素材要求：** 仅允许来源可追溯、许可证明确的资源；Kenney CC0 可按许可证使用。禁止密钥、私人日志、构建产物、IPA、可执行二进制、模型权重。不得将未经审计的大型档案直接加入源码提交。

## 5. 与 VeilLink 的集成关系

`dev/veilopoly` 是**研发分支**，不是发布分支，也不是 Integration Governor 的替身。P1–P4 完成后由 Governor 审核、选择待集成变更，验证后再按正式门禁处理。P5 的 VeilLink 真实 GameTransport、聊天/游戏大厅入口 UI 属于**独立授权项目**，不得提前开始。

任何显示“通过”的 Linux XCTest 都不能冒充 iOS Simulator、真机或两设备联机验收。

## 6. 与现行 main 规则的协调

`main:AGENTS.md` 规定 INBOX_ONLY 是默认模式，只有 Owner 显式授权或 Governor `[LIVE-LANE-GRANT]` 才能获得直接源码修改许可。本文件是在 Owner 新指令下对 **单个专用分支的狭义例外**，绝不通过分支中的文档去修改 `main` 全仓宪法。此授权同时应登记在 Issue #6 以便所有 Lane 查询。
