# Veilopoly P4 · 真横屏全屏及双按钮胶囊交互规范

**签发范围：** `dev/veilopoly:VEILOPOLY_DEV/Veilopoly/**`，独立 P4 UI 实现。P5 宿主接入不在本次授权内。

## 目标

1. 全屏 `fullScreenCover`，请求 `UIWindowScene` 横屏方向（iOS 16+），**不是把竖屏界面旋转 90°，也不是竖排容器里的横向卡片**。
2. 横屏时左侧棋盘（完整展示 40 格，不裁切）、右侧独立滚动操作栏；SpriteKit 保持 `1024:940` 逻辑画布长宽比。
3. 背景延伸到物理屏幕边缘，内容遵循 safe area；不覆盖刘海、动态岛与交互手势；隐藏状态栏和常驻系统覆盖（系统控制仍由 iOS 决定）。
4. 右上角微信小程序语义的**两段胶囊**：左侧 `•••` = 更多，右侧圆环内实心点 = 退出，分隔线清晰、单键触控范围 46×44pt，支持 VoiceOver。
5. 更多 = 重新开局、本局信息；退出先确认，再通过回调或 `dismiss()` 返回展示它的上一层，不调用 `exit(0)`，不修改 VeilLink 主导航。
6. 画面方向不支持时展示说明页，不假装锁横屏成功；物理设备横竖屏切换的结果必须实测。

## SwiftUI 接入（未来 P5 的适配参考，不代表已集成）

```swift
@State private var isVeilopolyOpen = false

Button("开始 Veilopoly") { isVeilopolyOpen = true }
  .veilopolyFullscreen(isPresented: $isVeilopolyOpen,
                       seed: 1729123,
                       humanCount: 1)
```

- 调用点：App 宿主的 `View`；**当前只有 P4 可复用入口**，尚未加入 VeilLink 聊天/游戏大厅。
- Host iOS target `Info.plist` 要允许 `UIInterfaceOrientationLandscapeLeft` 和 `UIInterfaceOrientationLandscapeRight`（`UISupportedInterfaceOrientations`，iPad 要检查 `~ipad` 分支），同时按产品需求保留 portrait。
- `UIWindowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .landscape))` 会要求系统改变界面方向；**不会绕过 Info.plist 或宿主/容器的 `supportedInterfaceOrientations`**。宿主根控制器若只允许竖屏，须在 P5 增加有范围的方向授权/容器支持，并在退出时恢复原方向。
- iPad 分屏/Stage Manager、系统方向锁定、不同 VC 栈的表现要实机测试。API 返回失败时不能把横屏记为通过。
- 不要求改动 `Protocol 4`、`VLGM1`、`SQLite Schema V8`、GameState、RNG、逻辑引擎或发布管线。

## 双按钮胶囊的视觉要求

| 项目 | 约束 |
|---|---|
| 位置 | 操作栏最上方靠右，在屏幕安全区内 |
| 左键 | 三点图案 · 46×44pt 点击区 · 菜单 `更多` |
| 右键 | 同心圆退出图案 · 46×44pt 点击区 · 二次确认 |
| 分隔 | 1pt × 24pt，半透明中性颜色 |
| 外壳 | 圆角胶囊，亮色表面 + 深色图案，适应暗色游戏背景 |
| 触达 | VoiceOver 各自的独立标签，系统动态字号场景需复核 |
| 点击 | 更多不退出；退出不展开更多；退出和动画快进互不影响 |

参考截图由 Owner 提供，但图片含用户账户资料，**不进入 Git 历史**；这里只保留无个人信息的交互设计规格。

## 验证门禁

已验证：Linux Swift 6.2.1 源码可解析、Swift Package build、`LandscapeLayoutTests` 的可移植布局约束。

未验证：Apple SDK 的 SwiftUI/UIKit 类型检查、iOS 16 实际横屏切换、`fullScreenCover` 全屏、安全区、不同 iPhone/iPad 的触控命中及相机/动画 ACK、双胶囊菜单和退出回调的运行行为。验收以上内容必须使用 macOS/Xcode 与设备/模拟器。
