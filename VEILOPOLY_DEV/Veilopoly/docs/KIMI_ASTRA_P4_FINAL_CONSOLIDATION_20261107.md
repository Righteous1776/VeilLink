# Veilopoly P4 · Kimi/Astra 运行时合流验收记录（2026-11-07）

**Task:** `VL-P4-KIMI-ASTRA-UNIFIED-20261107`  
**Branch:** `dev/veilopoly`  
**Baseline:** `629f7534ac7645db55304304b28040d48ccb2750`

## 实际合流内容

| 范围 | 代码／资源 | 状态 |
|---|---|---|
| Kimi 棋盘 15 张 | 15 个原始 Git Blob 复用到 SwiftPM `Resources/`，合计 519,024 bytes | 入库完成 |
| Kimi K2 动态棋盘 | `KimiK2BoardSkin.swift` + `BoardScene.swift` | 接线完成，iOS 未验收 |
| 40 格坐标、UV、命中区域 | `KimiK2TileMap` + `KimiK2AtlasGeometry` + 原生 ShapeNode 命中层 | 接线完成 |
| 地块文字 / 价格 | 现有 `GameState`，不使用 Kimi 演示文字 | 已接线 |
| 所有权 / 抵押 | Kimi ownerStripes / tileMortgageOverlay，根据真实状态懒创建 | 已接线 |
| 房屋 / 旅馆 | 复用既有 K1 的 house / hotel 原图，状态变化时懒创建 SpriteKit 节点 | 已接线 |
| 四玩家棋子 | `kimiTokenPawnBlue`、`kimiTokenCarRed`、`kimiTokenShipGreen`、`kimiTokenPlaneYellow` | 资源已入库，BoardScene 使用原有贴图回退 |
| 六态地块特效 | `kimiFxTilePulseAtlas` | 已接线，旧程序脉冲回退 |
| 金币 / 回合横幅 | `kimiFxCashChipAtlas`、`kimiFxTurnBanner` | 已接线，保持动画 ACK 回收 |
| 其他 3 张资源 | PawnShadow / VictoryBadge / CardFaceFrame | 已入运行时资源库、未启用；防止与 Astra UI 冲突 |
| 浅色 Kimi 棋盘、specialIconsMask | 属于原 15 张；完整保留 | 已入运行时资源库、未启用 |
| Astra B01 20 张运行时资源 | 原按钮／5 张交易 hero／玩家 HUD | 原样保留 |
| 横屏交互与退出 | 右下角操作入口、右上角 More/Exit 双键胶囊 | 原样保留 |

**增量 PNG 数量：25 张，原始压缩字节合计 897,638。** 这不是内存占用值；SpriteKit 解码后的纹理显存需实测。

## 资源安全与重复仲裁

- Kimi K2 新一代 15 张棋盘视觉优先于旧 `K2/assets/board/board-base.png`，不重复引进旧 1 MB 底板。
- K1 原房屋、旅馆、骰子、音频继续沿用，不复制二次资源。
- Kenney 的 4 枚新棋子以不同 `kimiToken*` alias 引入，不覆盖旧 `pawnBlue/carRed/shipGreen/planeYellow`。
- PBR 贴图原始 ZIP、OGG 录音、字体与 18 枚备选棋子未直接引入运行时：需要纹理优化、音频格式和字体许可审查，不应作为无意义大包覆盖工程。
- `VEILOPOLY_DEV/INCOMING_ASSETS/**` 保留来源与哈希；生产代码没有复制外部素材包的规则/文字。
- 新 BoardScene 在缺少完整必要贴图时返回旧程序化棋盘；Kimi 验收并不放宽 Astra 的操作、动画 ACK 与游戏引擎硬门。

## 验证完成与未完成

**完成：**
- 15 张新棋盘资源与 10 张 K2 追加素材在各自来源核验 SHA-256，GitHub 上传过程中核验 Git Blob SHA-1；真实文件入 SwiftPM 资源库。
- 使用原始 `SPRITE_MAP.json` 逐项验证 40/40 图集帧非透明、边界、UV 坐标和四角旋转。
- `KimiK2RuntimeResourceAudit` 新增资源存在性 / 文件长度 XCTest；`KimiK2SpriteKitIntegrationTests` 新增 iOS SpriteKit 40 格坐标与缺图回退测试源码。
- 与集成前 `629f7534` 对比，新增及修改均在 `VEILOPOLY_DEV/**`。

**未执行：** 与 GitHub 当前 HEAD 完全对应的 SwiftPM XCTest、Xcode iOS 编译、iPhone/iPad 真机/模拟器触控、VoiceOver、安全区、FPS/显存、500 seeds AI、P5 VeilLink 主 App 真正入口/打包测试。Linux 的 SpriteKit 条件编译区不等于 iOS 编译通过。

## 下一步门禁

1. Apple Xcode 先跑 iOS 16+ clean build，执行新增 Kimi XCTest 与现有 Engine/Net/Astra 全套测试。
2. 横屏 iPhone 844×390、852×393、iPad 1180×820 测试四角纹理是否正确、格子点击区域、棋子移动/跳过动画 ACK 和建造节点状态变更。
3. 实机压力测试确认纹理显存、低帧率回退、VoiceOver 与资产交互没有遮挡。
4. 只有全部通过后再由 Governor 审核 P4 投递，**不可直接把未验收的游戏合并 main 或出 IPA**。
