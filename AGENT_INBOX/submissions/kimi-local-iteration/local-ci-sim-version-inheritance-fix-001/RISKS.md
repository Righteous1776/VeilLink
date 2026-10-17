# RISKS — local-ci-sim-version-inheritance-fix-001

## 本次变更风险
- **低**：仅改本地仿真脚本，零产品代码改动；最坏情况是门禁误报，不影响构建产物。
- 三处“降级”均为显式注明且有兜底：AgentCoordinator（CryptoKit，macOS CI 兜底）、MaleCNSGraphManager（产品漂移，脚本侧排除并 info 注明）、慢速自对弈 smoke（脚本默认跳过，可手动开启）。
- 两处“范围收窄”（A10Ultra 排除出 A9 无证明断言、TacticalState 禁令限定 foundation）都是随产品治理演进的对齐，收窄前逐字核实过新代码的合法性与设计意图，未放开任何仍生效的约束。

## 回滚
`git revert` 单文件即可，无数据、无迁移、无外部依赖。

## 上报：需 Governor/Owner 裁决的产品漂移（不属于本 patch 范围）
1. **MaleCNSGraphManager.swift 编译必挂**：`VeilLink/Agent/MaleCNS/MaleCNSGraphManager.swift` 引用 `VeilA9ComputeGovernor.bindMaleCNSConsumer`，该方法已在 455e550（MaleCNS 迁出 Core）中删除。该文件被排除在 Core target 之外所以日常构建不炸，但 `malecns-heavy-validation` 的 dual-brain 工具链一旦编译它必然失败。需要裁决：恢复绑定 API，还是更新 MaleCNSGraphManager 以适配现行 Governor。涉及 A9/A10 保护面，INBOX_ONLY 下我不动产品树。
2. **Issue #8 建议关闭**：publish-build55.yml 的权限问题已在 8bcde6a 修复并有“反发布证明”步骤，Issue 仍为 open 状态，与代码现状不符。

## 治理合规自检
- 未触碰 Protocol 4 / VLGM1 v1 / Schema V8 / 身份密钥 / 传输存储 / 恢复机制 / A9-A10 治理 / 发布门禁
- 未将 weights.npz / brain.npz / MaleCNSReference.vfly 引入任何地方
- 未借用 VEILLINK-ASSET-GAME-001；asset_grant: none
- 状态仅声明 DROPPED；未伪称任何未执行的测试
