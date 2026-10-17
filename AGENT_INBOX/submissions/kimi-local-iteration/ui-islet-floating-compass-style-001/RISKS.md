# RISKS — ui-islet-floating-compass-style-001

## R1 依赖链加深（高）

基线 = main + #40 + #43 + #44。本补丁与 #44 在同一批分支点相邻插入（AppearanceTheme 枚举/switch、AppTheme 三处 if 链、AdaptiveRootView 根分支），文本上严格接续 #44 终态——若 #44 被修改，本补丁须重生成。若评审希望浮屿独立于白描，可重制（两包在同一批位置各加分支，后合者必然冲突，须手工调和）。

## R2 新导航范式的可用性（中）

罗经胶囊把五分区入口收进一次点按 + 一次选择（原 TabView 为一次点按直达）。代价：切换多一步；收益：内容区完整、界面无永久占位。这是 Zeo「以另一种方式呈现底部栏」的刻意取舍，可否决。新装用户发现性：胶囊常驻且有展开箭头，配合主题副标题文案引导；真机走查须重点验证发现性与单手可达性。

## R3 未验证项（如实）

- xcodebuild/xcodegen 真编译：NOT RUN（Linux 沙箱；xcodegen 目录通配自动收新文件，仍须 macOS CI 确认）。
- XCTest / 真机渲染 / 弹簧动效手感 / VoiceOver 走查：NOT RUN。
- safeAreaInset 与既有各分区 ScrollView 的 inset 叠加行为：按 SwiftUI 标准语义预期自动让位，真机 NOT RUN。

## R4 保护面

零触碰全部保护面；纯 UI 框架层新增（1 新文件 + 3 处分支）。M5 保持 shadow，production_cutover=DENY。回退成本 = 还原 4 文件。

## R5 降回兼容（低）

旧版本读到持久化的 `islet` 原始值时，`VeilAppearanceSelection(rawValue:)` 失败落既有缺省（veilOriginal），不会崩溃。
