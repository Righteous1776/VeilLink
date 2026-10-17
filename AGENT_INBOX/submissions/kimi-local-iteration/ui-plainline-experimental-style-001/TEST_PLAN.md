# TEST_PLAN — ui-plainline-experimental-style-001

基线组成：main `a48be36` + PR #40 + PR #43（依赖已声明）。环境：Linux 沙箱，Swift 6.0.3（parse/typecheck 门禁），无 Xcode。

## 已执行（本环境）

| # | 门禁 | 命令/方式 | 结果 |
|---|---|---|---|
| 1 | Swift 语法解析（5 个改动文件） | `swiftc -parse` | PASS |
| 2 | 标准预检 | `python3 scripts/ci-standard-preflight.py` | PASS（含 verify-ui-theme-r9 修订后断言、323 文件 parse） |
| 3 | 补丁反向校验 | 干净基线克隆上 `git apply --check -R PATCH.diff` | PASS（6 文件块与目标树严格对应） |
| 4 | 基线组成核验 | base 未提交改动与 PR #43 PATCH.diff 逐字节 diff | PASS（完全一致，#40 已独立提交于基线历史） |
| 5 | 模拟断言字面量 | AdaptiveRootView 内 `.tabItem { Label("灵核"`、`AgentHomeView(model: model)`；SettingsView 内 `model.runA9StorageCheck()`；Models.swift `case agent = "灵核"` | PASS（逐字保留） |
| 6 | local-ci-sim.sh（修复版，26 阶段） | `bash scripts/local-ci-sim.sh` | 见下方结果 |
| 7 | 授权 API 语义核读 | `AppLockController.unlock(pin:)` 源码逐行核对：未启用→安全 false；错误→计数+锁定（5→30s/8→300s）；成功→清锁定 | PASS（仅核读，零修改） |

## 未执行（如实声明）

- xcodebuild / xcodegen 真编译：NOT RUN（须 macOS / GitHub CI）。
- XCTest 全量：NOT RUN。
- 真机/模拟器渲染、切换流、授权流联调：NOT RUN。
- 模拟器测试不冒充真机验证；本包一切结论以「本地文本/语法门禁 + 既有真 CI 历史」为限。

## 合并后建议（Owner/Reviewer 侧）

1. macOS CI：`xcodegen generate` + `xcodebuild` + XCTest 全量。
2. 真机走查：三原风格逐页回归（应零变化）→ 白描授权开启 → 五分区切换 → 退出白描 → 未设应用锁设备的引导路径。
