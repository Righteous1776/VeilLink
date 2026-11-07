# Veilopoly 研发路线和验收

| Phase | Scope | Gate | Status |
|---|---|---|---|
| P1 | 40 格棋盘、G/ctx/Player/Tile、15 种 move、种子 RNG、数据驱动卡牌、破产清算 | 建模规格 §8 基线 1/2，决定性重放、统一 GameError | Linux Swift 6.2.1 本地复验通过；GitHub CI 待验证 |
| P2 | 4 人本地循环、AI 三档、拍卖、交易 | 500 种子 AI 有界压力测试无引擎错误；自然完局率另报 | Linux 有测试结果；待独立复验 |
| P3 | host-authoritative log/seq/hash/snapshot/resync，`GameTransport` 协议 | 乱序/丢包/补发/哈希不一致测试；真实 VeilLink 适配器空实现 | Linux 有测试结果；待独立复验 |
| P4 | SpriteKit L0–L7、骰子 1.2 秒、逐格 150ms、可快进、ViewCommand ack、SwiftUI 互动面板 | iOS 16 SDK 构建、Simulator & 设备交互/动画/音效验收 | 源码与资源已入库，仍未获 iOS SDK 验证 |
| P5 | VeilLink 真正 GameTransport、聊天/大厅入口、发行集成 | 另行 Owner 授权 + Governor 审核 + 端到端实测 | **禁止提前启动** |

## 必守技术契约

`VeilopolyEngine` 不导入 UIKit、SwiftUI、SpriteKit；禁止 `Date()`、`UUID()`、`Int.random` 以及浮点比较。随机只走 `seededRNG(seed, &rngCounter)`；状态哈希及日志需确定性；AI 产生标准 move；UI 仅消费 Effect + 快照，以 ViewCommand ack 作为 phase 前进门。

## 待规格裁决 / 阻塞清单

- 32 张卡牌的完整正式内容与测试牌组的区别；
- 拍卖、破产清算等边界细节若原规格未明确，不得默认为正式规则；
- 规格中的素材相对路径必须与实际资源布局重新校验；
- iOS SDK 无法通过 Linux Swift 测试代替，必须补验证。

本开发区优先完成 P4 验收和完整端内 loop，而不是扩张到 P5。


## 2026-11-06 迁入修订
独立分支源码及资产已写入；Linux Swift `swift build` 成功，31/31 XCTest 分两次筛选运行通过。500 seeds 每局 500 move 上限仅证明无非法 move（0/500 自然完局），20 seeds 每局 6000 move 上限有 14/20 自然完局。iOS/Xcode/UI 全链路仍未验收，P5 未授权。
