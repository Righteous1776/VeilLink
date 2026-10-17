# PROPOSAL — local-ci-sim-version-inheritance-fix-001

## 问题
`scripts/local-ci-sim.sh`（仓库自带的本地 CI 仿真门禁）在当前 main（a48be364, v26.12-b58）上**无法跑通**：多处断言仍锁定旧版本源码形态，导致任何开发者在 Linux/macOS 本地执行该脚本都会立刻失败，门禁失去意义。

## 证据链（全部本地可复现）
基线 a48be364 上直接执行 `bash scripts/local-ci-sim.sh`，首处失败为 Python 断言 `assert f'V{version} ' in current`——自 e0c7adb 起 Info.plist 改用 `$(MARKETING_VERSION)` 变量继承，脚本未跟进。修复后继续暴露出一连串同类漂移，共 20 处，全部逐一核实当前源码后修复（详见 PATCH.diff）。

## 漂移分类
1. **版本继承**：Info.plist 用 `$(MARKETING_VERSION)` / `$(CURRENT_PROJECT_VERSION)`，改为校验 project.yml base settings 与 CHECKPOINT 文本一致性。
2. **可复用工作流间接层**：unsigned-ipa.yml 的 package job 经 `uses: ./.github/workflows/core-release.yml` 委托，脚本需跟随一层再校验 artifact 名。
3. **新增源码未纳入编译闭包**：VoiceMessageCodec、AgentLocalContext、VeilLatticeKernelBridge、RuntimeMaintenanceTuning、MaleCNSLearnedReadout、MiniGames/TacticalGame/ArcadeGames/MagneticHockeyGame 等。
4. **产品 API 演进**：
   - BLELinkReliabilityPolicy 重构（packetBurstLimit / interBurstDelay / normalizedRSSI / reconnectDelay 单调性，quality(nil)==.unknown）
   - BLEPeerLinkSnapshot 增加 transportStage；状态文案“自动重连中”；contributesLinkQualityToA9
   - SidebarSection 增加 `.games`（五 tab）
   - A9ComputePlanner 增加 `allowExperimentalCore`（默认 false → .lite；显式开启 → .core）
   - MaleCNS rollout pool 自 77bc0a4 起单 tick 刺激（[2,1,3]，total 3）
   - AgentHomeView 构造签名改为 `(model:)`；`AgentHomeView(model: model)` × 2 处
   - AppModel 不再持有 MaleCNSGraphManager（455e550 Core 隔离，断言反转为“不出现”）
   - A9ComputeGovernor 移除 bindMaleCNSConsumer（455e550），plan 经 `VeilA9ComputePlanner.plan(` + `onPlanChanged?(plan)` 流转
   - ToolCenterView 改用 VeilSkeuomorphicPerformance.currentBudget / allowsBackdropMaterial
   - dedicatedLocalPolicyKinds 扩展为 [.tactical, .artillery, .lightTrail, .magneticHockey]（6265136）
   - TrainedGamePolicyRuntime 的 tactical 排除分支同步扩展
5. **门禁扫描范围修正**：
   - A10UltraOmegaShadow.swift（f57a308，正式 A10 shadow 治理）合法固定 SHA256 谱系；Health 无证明断言限定到 A9 健康面
   - Agent/Games（6265136+）的 bot 按设计引用 TacticalState；TacticalState 禁令限定到助手 foundation
   - 空白字符守卫跳过 AGENT_INBOX（他 agent 已落库的提交物不可改）
   - MaleCNSGraphManager.swift 引用已被 455e550 删除的 `VeilA9ComputeGovernor.bindMaleCNSConsumer`，任何编译闭包都过不了——**这是产品漂移，不是脚本问题**，脚本侧以 info 说明并排除该文件，产品侧问题另案上报（见 RISKS.md）
   - AgentCoordinator 闭包依赖 CryptoKit（Apple 专有），Linux API-shape 阶段缩减为 26 文件闭包并以 info 注明 macOS CI 覆盖
6. **MiniGame 回放确定性**：actionID 为进程随机 UUID，回放时间戳不可做绝对断言，改为相对不变量（重复 rebuild 时间戳相等、非哨兵值）。
7. **UIKit/Linux stub**：FeedbackStyle 补 `.heavy`；heavy-validation 合约改为校验 Tools/VeilFlyBuilder 工具链存在性与现行委托字符串。

## 原则
每处修复都对照当前源码逐字核实；门禁意图只随产品真实演进而迁移，未削弱任何一条仍在生效的约束；无法本地覆盖的（CryptoKit、xcodebuild 真机编译）显式降级并注明仍由 macOS/GitHub CI 把关。

## 附带发现（不在本 patch 内修复）
- Issue #8 所述 publish-build55.yml 权限问题已在 8bcde6a 修复（`permissions: contents: read` + 反发布证明步骤），Issue 仍开着，建议 Owner 关闭。
- MaleCNSGraphManager.swift 引用不存在的 `bindMaleCNSConsumer`——malecns-heavy-validation 的 dual-brain 构建必然失败，需 Governor/Owner 裁决（见 RISKS.md）。
