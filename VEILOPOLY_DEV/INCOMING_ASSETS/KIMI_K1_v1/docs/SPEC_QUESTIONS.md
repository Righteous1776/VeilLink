# SPEC_QUESTIONS · 待裁决清单（K1，2026-11-06）

> 对齐仓库 `SPEC_DECISIONS_REQUIRED.md` A01–A13。视觉线不擅自定规则；以下是提案与问题，**等 Owner 裁决**。

## A01 40 格冻结数据 —— 建议采纳
**提案**：以 `model/board.json` 为正式机器源（40 格全量：中文名、色组、价格、租金梯度、房屋成本、布局坐标）。
状态：已生成并校验；K1 包 `sources/` 含 board-layout.png 可视化。→ 请 Owner 批准为 formal source。

## A02 卡牌池 —— 提案供裁决
**提案**：`model/cards.json`（机会 16 + 命运 16，Effect 数据驱动）。差异说明：
- C05/C06 两张「最近铁路双倍租金」按经典版保留两张；
- 出狱卡规则建议：使用后移出游戏（不入回牌堆）——请确认；
- T14 修缮费按 GDD 统一 perHouse 25 / perHotel 100（经典 chest 版为 40/115，已对齐 GDD）。

## A05 拍卖 —— 视觉线建议（不影响引擎接口）
低 connectivity 场景建议**非时钟制**：轮流出价，弃购者退出；最高者得。若加时钟，建议房主权威 15s 每口。→ 待裁决。

## A06/A07 交易与清算 —— 纯规则，视觉线不提案
仅确认：破产清算链（抵押→匀卖建筑→再抵押→declareBankruptcy）的动画时序已按 ANIMATION_TIMELINE §5 排好；交易面板 UI 支持「带抵押标记地产」显示（红色斜杠随交易转移显示）。

## A11 渲染 ACK —— 建议确认（K1 已按此冻结）
建议裁决：「渲染 ACK 走 session coordinator，coordinator 在最后一个 ViewCommand ack 后调用纯引擎」为绑定契约。K1 的 ANIMATION_TIMELINE 全部按「一次完成事件」编写。

## A13 性能验收 —— 视觉线配合
建议真机验收协议：iPhone 8 基线 + 种子语料 20 局，记录启动时长/动画期 CPU/帧率。视觉线交付 atlas 建议（SPRITE_MAP.json）已按 <250 节点设计。→ 待 Owner 定 telemetry 方案。

## 视觉线新增问题
- **Q-K1-1**：iPad 横屏是否支持双人对坐模式（棋盘旋转 180° 面对面）？当前 LAYOUT_SPEC 按单视角设计。
- **Q-K1-2**：卡牌正背可选皮肤（cardChanceAlt/cardChestAlt 已备）是否进设置项？默认仍用经典蓝/绿。
