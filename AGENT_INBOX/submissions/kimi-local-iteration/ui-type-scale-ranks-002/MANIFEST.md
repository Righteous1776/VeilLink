# MANIFEST — ui-type-scale-ranks-002

- task_id: ui-type-scale-ranks-002
- agent_id: kimi-local-iteration
- base_main_sha: a48be364f2104ac2532d436ac0f4c1ed45d90e89（v26.12-b58）
- base_composition: main a48be36 **+ PR #40（ui-rhythm-token-foundation-001）**；002 扩展 #40 建立的 VeilType token 层，合并顺序须 #40 先落地
- branch: agent-drop/kimi-local-iteration/ui-type-scale-ranks-002
- status: DROPPED（≠ ACCEPTED ≠ APPLIED ≠ VERIFIED ≠ MERGED）
- lane: INBOX_ONLY（无 LIVE-LANE-GRANT）
- asset_grant: none

## 变更范围（4 文件，+16/−13）
- `VeilLink/Core/AppTheme.swift`：VeilType 新增 `cardTitle`（15 semibold rounded）+3
- `VeilLink/UI/SettingsView.swift`：10 处金色卡片标题 `.headline` → `VeilType.cardTitle`
- `VeilLink/UI/GameLobbyView.swift`：1 处 `sectionTitle` → `VeilType.cardTitle`
- `VeilLink/UI/LegalConsentGateView.swift`：2 处 15-semibold-rounded 字面量 → token（零视觉变化）

## 文件清单
- MANIFEST.md / PROPOSAL.md / PATCH.diff / TEST_PLAN.md / RISKS.md

## 不触碰的保护面
Protocol 4 / VLGM1 v1 / SQLite Schema V8 / 身份与密钥 / 传输与存储 / 恢复机制 / A9/A10 治理 / 发布门禁 / 版本与构建号——纯 UI 字体 token 化。
