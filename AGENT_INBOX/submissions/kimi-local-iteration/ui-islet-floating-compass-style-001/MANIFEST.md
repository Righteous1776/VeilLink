# MANIFEST — ui-islet-floating-compass-style-001

- agent_id: kimi-local-iteration
- task_id: ui-islet-floating-compass-style-001
- status: DROPPED（≠ ACCEPTED ≠ APPLIED ≠ VERIFIED ≠ MERGED）
- date: 2026-10-17
- lane: INBOX_ONLY（五件套投递，无产品树直接修改）

## 基线与依赖（顺序重要）

1. main `a48be36`（fix: restore legal signing interactions, #39）
2. PR #40 `ui-rhythm-token-foundation-001`
3. PR #43 `ui-type-scale-ranks-002`
4. PR #44 `ui-plainline-experimental-style-001`
5. 本补丁（最后应用）

在干净基线（main+#40+#43+#44）上 `git apply --check -R` 反向校验通过，补丁与目标树严格对应。

## 变更文件（4）

| 文件 | 变更 | SHA-256（补丁应用后） |
|---|---|---|
| VeilLink/Core/AppearanceTheme.swift | islet 案例 + 昼夜双调色板（深海/雾珠） | a5ef7fe092972da31136991902e90645924c47dd61fc8f4e90c37fb19be58d91 |
| VeilLink/Core/AppTheme.swift | 渐变/背景/卡片/按压四处浮屿分支 | db44c277ad2a2b3320735895f37963117280b67e58a8fe94e061ffadc4331441 |
| VeilLink/UI/AdaptiveRootView.swift | +4/−1：根容器浮屿分支 | 205de6b2aedbc206fb4a1122d888f42a5fbb40759e404389a52a40fd62bfc368 |
| VeilLink/UI/IsletRootView.swift | 新增 211 行：极光底色 + 罗经胶囊导航 | 897d808c1c61d2bde42fd54de5bcfd5c89bd5e46492bb825e684905229eb61e0 |

- SettingsView.swift 零改动：浮屿为普通样式，`switchableCases` 自动收编进主题列表
- PATCH.diff：443 行，4 个文件块，+307/−6
- PATCH.diff SHA-256：`c4889d29b7033c58cea062b6badeeb0c38fbfac70795325c0bd4ac204312b00e`

## 保护面声明

未触碰：Protocol 4、VLGM1 v1、SQLite Schema V8、身份与密钥、传输与存储、恢复机制、A9/A10 治理、签名/发布/版本门禁。纯 UI 框架层新增。M5 维持 shadow，production_cutover=DENY。
