# Veilopoly 双 Agent 协作协议 / VL-POLY-COLLAB-001

**生效日期：**2026-11-06
**Owner：**负责规则裁决、需求、两侧交付确认。
**ChatGPT：**Swift 工程 Owner / Engine Integrator。
**Kimi：**Visual & Asset Lead / 2.5D Modeling & Rendering Specification。

## 并行职责（代码层与艺术层分离）
| 区域 | ChatGPT | Kimi |
|---|---|---|
| VeilopolyEngine Swift | 实现/测试/审核 | 只读，提出规格问题 |
| VeilopolyAI Swift | 实现/测试 | 只读 |
| VeilopolyNet 协议抽象 | 实现/测试 | 只读 |
| VeilopolyUI SwiftUI/SpriteKit | 实现/渲染接线/真机验收 | 动画规格、画面/交互视觉蓝本、标注和素材 |
| 2.5D 棋盘、棋子与场景 | 适配/性能测试 | 设计、建模、图集、导出 |
| PNG/纹理/声音和版权记录 | 接收、校验、Git 提交 | 搜集、授权审计、优化、输出 |
| 规则与卡牌 | 实现被正式批准的规则 | 只提出建议，禁止擅自改动 |
| main / P5 / Release | Governor 审核后处理 | 无权限 |

## 交付链路

`Kimi -> Owner（文件上传给 ChatGPT） -> ChatGPT 校验/入库 dev/veilopoly -> CI/人工核验 -> Governor 审批集成`

Kimi 不能直接访问/写 GitHub 仓库；**Kimi 的“已交付”不代表 GitHub“已入库”**。ChatGPT 也不得声称未上传的内容已集成。每次只接收有版本号和 manifest 的完整/增量包；包内必须说明具体更改了哪些 alias、布局、动画参数，避免由名字猜测资源。

## 并行冻结界面

- Kimi 不覆盖 Swift engine、AI、网络、GameState、Move、Effect 类型。
- ChatGPT 不凭审美擅自修改 Kimi 已签收的素材契约；实际性能/兼容问题需反馈证据。
- Kimi 定义抽象视觉事件与规格，不强制逻辑引擎 import 渲染框架。
- 所有渲染接线用 `ViewCommand` / `CommandTranslator`；动画完成 ACK 送 coordinator，由 coordinator 推进引擎，不从 SpriteKit 直接运行规则。
- 规格存在歧义必须记入 `docs/SPEC_DECISIONS_REQUIRED.md` 并由 Owner 决策。

## 权限底线

Kimi 素材与 ChatGPT Swift 都只进入 `dev/veilopoly:VEILOPOLY_DEV/**`。不得修改 main、VeilLink 传输协议、SQLite Schema V8、版本号、签名和发布工作流。P5 另行授权。

## 交付审查清单

1. 所有素材文件在 manifest 中有 path/alias/用途/原始 URL/license/SHA-256/bytes/导出尺寸。
2. PNG / 可读取矢量 / 纹理序列均有 iPhone 与 iPad 的标注，以及 safe area 和可点击区域。
3. 2.5D 视觉不修改 40 格布局逻辑索引；支持 4 个棋子在同格扇形展开。
4. 12–15° 桌面倾角；L0–L7 分层；骰子 1.2s、每格走子 150ms，可快进；快进必须 ACK 一次且只有一次。
5. 场景资源缺失时应有可识别占位，不产生空白或卡死。
6. 能单独审查的中间成果与最终导出；规格和素材版本需要能关联到同一个 SHA-256 manifest。
7. Kenney CC0 原素材须保留源站与许可证明，任何新资源额外核验许可证。
