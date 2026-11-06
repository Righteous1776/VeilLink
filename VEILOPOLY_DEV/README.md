# Veilopoly · 大富翁游戏开发区

> VeilLink 独立游戏研发域 / Independent Veilopoly development area.

**Git branch:** `dev/veilopoly`  
**Development root:** `VEILOPOLY_DEV/`  
**Owner authorization:** 2026-11-06, Owner explicitly requests a Veilopoly development branch parallel to Inbox.  
**Base main commit:** `ccafebab147e069fbabfff579dbf323b0d54f191`

## 定位

本开发区与 `AGENT_INBOX/` 在**研发提交渠道**上平行，独立接收、管理、迭代 Veilopoly 的游戏代码、规则、测试、文档与已获许可素材。它不是 `AGENT_INBOX/submissions/` 的子项目，也不要求 Veilopoly 的所有日常实验先转换成 Inbox 提案。

这不等于提升到 Repository Owner 或 Integration Governor 层级，不代表获得直接合并 `main` 或发布 IPA 的权限。**两个开发渠道统一由 Integration Governor 审核和集成。**

## 目录约定

- `VEILOPOLY_DEV/GOVERNANCE.md` — 唯一明确的本分支范围、权限与硬门
- `VEILOPOLY_DEV/ROADMAP.md` — P1–P5 里程碑和验收清单
- `VEILOPOLY_DEV/CHECKPOINT.md` — 当前成果和未验证部分
- `VEILOPOLY_DEV/Veilopoly/` — 专用 Swift Package 的正式工作目录（P1–P4 源码、测试及 CC0 资源已迁入）
- `VEILOPOLY_DEV/reviews/` — 设计裁决、冲突分析和验证报告（需要时建立）

请勿将新的游戏代码写到 `AGENT_INBOX/`、VeilLink 的 `Sources/` 或其游戏大厅目录。P5 获得明确授权并完成验证后，方可由 Governor 将经过审核的代码集成至 VeilLink 产品源码。

## Agent 开始前的必读顺序

1. 获取最新 `main` 和当前 `dev/veilopoly`；
2. 阅读 `main:AGENTS.md`、`main:AGENT_INBOX/00_READ_ME_FIRST.md`、`main:AGENT_INBOX/01_GOVERNOR_IDENTITY.md`、`main:AGENT_INBOX/GOVERNOR_AUTHORITY.json`、`main:AGENT_INBOX/02_RULES.md` 与 Issue #6；
3. 阅读本目录的 `GOVERNANCE.md`、`ROADMAP.md`、`CHECKPOINT.md`；
4. 通读 `Veilopoly/docs/GAME_DESIGN.md`、`MODELING_SPEC.md`、`RENDERING_SPEC.md`；
5. 在授权范围内工作，独立分支提交，提供可审计变更和测试记录。

## 实现原则

- Swift 5.9+，iOS 16；`VeilopolyEngine` 保持纯 Swift、无 UI、无系统随机源；
- 确定性引擎 `(G, ctx, move) -> Result<(G', [Effect]), GameError>`；
- 单机和联机共用同一引擎；网络适配器在 P5 前保持接口级抽象；
- `VeilopolyAI`、`VeilopolyNet`、`VeilopolyUI` 与引擎分层；
- `Protocol 4`、`VLGM1`、`SQLite Schema V8` 及 VeilLink 传输层完全禁止修改；
- 不得用未经规格方裁决的假设偷偷补齐游戏规则。

**Coordination:** https://github.com/Righteous1776/VeilLink/issues/6

## 最新入库状态（2026-11-06）

已导入独立 Swift Package 的 43 个文本源码/文档与 26 个 PNG/WAV 资源，并生成资源完整性清单。最新 Linux Swift 6.2.1 本地 `swift build` 通过，29 个基础测试和 2 个 AI 压力测试分别通过。iOS SDK、SpriteKit/SwiftUI 实际运行仍未验证。参见 `CHECKPOINT.md` 与 `Veilopoly/docs/RESOURCE_INTEGRITY.json`。Kimi 使用 `KIMI_HANDOFF.md` 作为最新素材任务书。
