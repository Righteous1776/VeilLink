# PROPOSAL — 白描（Plainline）：第四种实验界面风格

## 任务来源

Zeo 直接授权：「全权设计一个新的 UI 操作界面」——(a) 保留原三种风格，新增第四种；(b) 允许整页大改，含底部工具栏；(c) 取好名字、支持切换，切换需在「设置」单独加一行开关、按下后输入授权码（密码）。附加约束：「但是还是要在简约的基础上」。

## 设计：白描

取中国画「白描」之意——不设色、不晕染，只以墨线立骨。落到界面：

- **无材质、无阴影、无渐变**：背景即纸（昼：暖白纸；夜：中性墨黑），卡片消解为分区，仅以 0.5pt 发丝线收尾。
- **只由排版、留白与发丝线组织**：层级靠字重与间距，不靠填充与描边。
- **单一金色承担信任与动作**：选中、未读数、风格记，全页只有一处色相。
- **页面骨架大改**：底部系统 TabView（图标栏）替换为「发丝文字通道」——五个文字通道，选中项头顶一画金色短线；顶部保留一枚衬线字标 + 当前分区名。内容与遥测 100% 复用既有五个分区视图，本风格只换框架（chrome）。

## 切换机制（按 Zeo 指定）

- 「设置 → 外观主题」内单独一行「白描 · 实验风格」。
- 点按 → 弹出授权页 → 输入**应用锁密码**（复用 `AppLockController.unlock(pin:)` 既有公开 API，零密钥面修改；错误计入既有锁定策略：5 次锁 30 秒、8 次锁 300 秒）。
- 验证通过 → 立即切换；**切回免费**（白描下行显示「退出白描」，点按直接回到默认风格，无需再验）。
- 未启用应用锁 → 授权页引导先前往「安全 → 应用锁」设置 6 位密码，不提供绕过路径。
- 白描为 `isExperimental`，不出现在三风格自由切换列表（`switchableCases`），只能经授权行进入。

## 变更摘要（6 文件，+404/−14）

1. `AppearanceTheme.swift`：`case plainline`、`isExperimental`/`switchableCases`、标题/副标题/预览、昼夜双调色板（goldDeep 拍平为 gold、metal/keycap 拍平为 panel，色板坍缩为纸墨金三色）。
2. `AppTheme.swift`：三条渐变在白描下扁平化；`VeilAmbientBackground`/`VeilCardModifier` 白描首分支（卡片→发丝线分区）；`VeilPressStyle` 白描下取消缩放/位移/阴影，仅留亮度与不透明度反馈。
3. `PlainlineRootView.swift`（新增）：`VeilPlainlineRootView`（字标头 + 五分区内容开关 + 发丝文字导航轨，保留 `navigation.tab` 遥测并附加 `chrome: plainline`）+ `PlainlineUnlockSheet`（授权闸门）。
4. `AdaptiveRootView.swift`：根容器加白描首分支；原 PhoneLayout/TabletLayout 逐字保留（模拟断言字面量完整）。
5. `SettingsView.swift`：主题列表改 `switchableCases` + 白描授权行 + 授权页接线。
6. `verify-ui-theme-r9.py`：1 行断言同步（`allCases`→`switchableCases`），见 RISKS 说明。

## 兼容性

- 三原风格逐像素不变（所有白描逻辑都在 `isPlainline` 首分支内，非白描路径零改动）。
- UserDefaults 键不变；新风格复用 `appearance.theme.selection.v1`，旧版本读到 `plainline` 原始值会落入既有 `rawValue` 缺省回退（unknown → veilOriginal），可安全降回。
- iPhone/iPad/深浅色均走同一白描框架（大改即大改，不保留平板双栏——实验风格的取舍，可评审否决）。
