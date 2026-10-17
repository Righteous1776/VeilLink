# TEST_PLAN — ui-islet-floating-compass-style-001

基线组成：main `a48be36` + PR #40 + PR #43 + PR #44（依赖已声明）。环境：Linux 沙箱，Swift 6.0.3，无 Xcode。

## 已执行（本环境）

| # | 门禁 | 命令/方式 | 结果 |
|---|---|---|---|
| 1 | Swift 语法解析（4 个改动/新增文件） | `swiftc -parse` | PASS |
| 2 | 标准预检 | `python3 scripts/ci-standard-preflight.py` | PASS（324 文件 parse + verify-ui-theme-r9 + 发布身份占位） |
| 3 | 补丁反向校验 | 干净基线上 `git apply --check -R PATCH.diff` | PASS（4 文件块与目标树严格对应） |
| 4 | 基线组成核验 | 工作树与基线树六文件逐字节 cmp（白描层） | PASS（全部 SAME 后才叠加浮屿） |
| 5 | 模拟断言字面量 | AdaptiveRootView `.tabItem { Label("灵核"`、`AgentHomeView(model: model)`；Models.swift `case agent = "灵核"`；SettingsView 未触碰 | PASS（逐字保留） |
| 6 | local-ci-sim.sh（修复版，26 阶段） | `bash scripts/local-ci-sim.sh` | 见 PR 描述补记 |
| 7 | 主题列表收编核验 | 浮屿非 `isExperimental` → `switchableCases` 自动含第 4 位；SettingsView 零改动 | PASS（源码核读） |

## 未执行（如实声明）

- xcodebuild / xcodegen 真编译：NOT RUN（须 macOS / GitHub CI）。
- XCTest 全量：NOT RUN。
- 真机/模拟器渲染、胶囊展开动效、单手可达性、VoiceOver：NOT RUN。
- 模拟器测试不冒充真机验证。

## 合并后建议（Owner/Reviewer 侧）

1. macOS CI：`xcodegen generate` + `xcodebuild` + XCTest 全量。
2. 真机走查：四原风格逐页回归（应零变化）→ 切浮屿 → 胶囊开合/五分区切换/未读微记 → 深浅色 → iPad。
3. 重点观察：罗经胶囊的发现性（新用户能否意识到它是导航）——这是本范式唯一真正的产品风险（RISKS R2）。
