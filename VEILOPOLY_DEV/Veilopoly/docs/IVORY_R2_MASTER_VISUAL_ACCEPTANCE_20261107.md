# Veilopoly · 正式象牙白主视觉基准（R2 / iOS 15）

**任务编号：** `VL-VEILOPOLY-IOS15-UNIFIED-20261107`
**裁决：** Owner 指定 `ivoryR1CenterInlay.png`（ID `VL-IVORY-R1-004`）为主图，不再使用其他中央装饰作为默认主图。

## 实际游戏代码对应
- Kimi 的浅色材料桌布/边缘/底板/外框 + Codex 精细地块 `astraTileFace`、十个特殊地块图标 + 新的象牙白中央嵌饰、两套机会/宝箱实物卡面、古金回合横幅都附着于 **单个** `Veilopoly/IvoryUnifiedBoard` SKNode，未改变 40 格设计坐标、GameState、触摸逻辑或镜头。
- 原来的 Codex `astraCenterCity` 和 Kimi 中央徽章保留为备用；不双重绘制。
- 建筑优先使用 Codex `astraHouseGreen` / `astraHotelRed`；玩家棋子优先 Codex 细节版本；买卖/银行/拍卖/交易仍使用 Astra B01 真正的 SwiftUI 交互控件。
- 象牙白是冷启动默认主题；夜间模式只是可选视觉变化。所有实时地块名称/价格/所有者、玩家现金/胜负由 Engine 驱动，不能烘焙进图片。
- 弹出的卡片信息使用象牙色动态面板，金边、深青绿色正文；HUD 保持有对比度的深青绿底和古金描边，与棋盘属于同一视觉系统，不做阻挡棋盘的永久侧栏。
- iOS 15 最低：SwiftPM `.iOS(.v15)`；iOS 16 场景旋转 API 已 availability-gate；iOS 15 使用公开旧旋转请求。对应 `IOS15_MINIMUM_COMPATIBILITY_20261107.md`。
- 对其他游戏的统一 iOS 15 要求，只登记为跨 Lane 兼容性标准，不跨越 `VEILOPOLY_DEV/**` 修改其他游戏或 `main`。

## 主图 / 展开操作状态设计验收图

- `visual/IVORY_R2_MASTER_BOARD_PREVIEW.png`：1024×940，使用原始 Kimi 浅色棋盘材料、真实 Ivory R1 中央牌面/卡面/回合条/建筑素材拼合。地块以 Codex 精细格子的**近似空白面板**呈现；图上只用序号辅助检查，真实 iOS 显示的名称和价格仍由 Engine 绘制。
- `visual/IVORY_R2_UNIFIED_INTERFACE_REVIEW.jpg`：完整象牙白/古金/深青绿的展开操作状态设计验收图。其右侧画面是布局示意，**不是**实际 SwiftUI / SpriteKit 真机截图，也不是默认常驻侧栏。
- 这些 PNG/JPEG 在 `docs/visual/` **仅用于视觉验收**，不作为 Runtime 全屏游戏背景，否则会丢失可点击地块、无障碍和可变状态。

## 核验
- 实际资源 `ivoryR1CenterInlay`、`ivoryR1ChanceCard`、`ivoryR1ChestCard`、`ivoryR1VictoryBadge`、`ivoryR1TurnBanner` PNG 解码 5/5 PASS。
- `IvoryUnifiedVisualSystem.swift` 的匹配 Foundation 纯状态注册接口在 Linux Swift 6.2.1 `-warnings-as-errors` 独立类型检查 PASS（配套源依赖使用测试 stub）；不表示 SpriteKit 真机编译。
- 已静态扫描 VeilopolyUI 30 个 Swift 文件的常见 iOS 16+ 接口；`requestGeometryUpdate` 和 `setNeedsUpdateOfSupportedInterfaceOrientations` 都在 `#available(iOS 16, *)` 下；`.scrollIndicators` 仅剩说明性注释。尚未执行 iOS 15 Xcode full build。
- SpriteKit 集成测试已随单容器结构更新，测试源码已提交，**未运行完整 XCTest / iPhone 7 iOS 15.8.3 实测**。

## 下一道真实门禁
Xcode iOS 15 deployment 编译，XCTest，iPhone7 横屏／40 格命中区／内存／动画／存档断电恢复，双设备联机重连。上述验收通过前不合并主线、不发布 IPA。
