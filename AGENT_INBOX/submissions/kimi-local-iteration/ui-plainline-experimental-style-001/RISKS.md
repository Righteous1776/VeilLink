# RISKS — ui-plainline-experimental-style-001

## R1 依赖顺序（高）

本补丁基线 = main `a48be36` + PR #40 + PR #43。若 #40/#43 被修改或弃置，本补丁须重生成。MANIFEST 已声明顺序；合并前请在干净基线上重新 `git apply --check`。

## R2 verify-ui-theme-r9.py 断言修订（中，须评审知情）

该预检脚本原断言 `SettingsView.swift` 含字面量 `VeilAppearanceSelection.allCases`。本任务把主题列表改为 `switchableCases`（实验风格必须移出自由切换列表，否则授权闸门形同虚设），故断言同步修订。
- 脚本意图保持：仍要求「外观卡片 + 枚举 API 驱动列表」，仍禁止硬编码风格清单。
- 不是为放行而放松：`switchableCases` 比 `allCases` 约束更强（多一层实验过滤）。
- 若评审拒绝，备选：保留 `allCases` 并在行内对 `.isExperimental` 分流（结构更绕，不推荐）。

## R3 实验风格的导航取舍（中）

白描在 iPad 上也不使用双栏布局，统一为单栏 + 文字通道。这是「整页大改」授权的刻意取舍；内容视图与遥测完全复用，功能面无损失。回退成本 = 还原 6 文件。

## R4 未验证项（必须如实知情）

- xcodebuild/xcodegen 真编译：NOT RUN（本环境 Linux，无 Xcode；xcodegen 按目录通配收文件，新文件无需登记，但仍须 macOS CI 确认）。
- XCTest / 真机渲染 / VoiceOver 走查：NOT RUN。
- 授权流真机联调（密码错误锁定、未设锁引导）：逻辑复用既有 `AppLockController.unlock(pin:)` 语义（源码已逐行核读），但真机 NOT RUN。

## R5 保护面

零触碰：Protocol 4 / VLGM1 v1 / SQLite Schema V8 / keychain·PasswordKDF 内部 / 传输与存储 / 恢复机制 / A9·A10 治理 / 签名与发布门禁。授权闸门仅消费 `AppLockController.unlock(pin:)` 公开方法；未启用应用锁时安全失败并引导设置。M5 保持 shadow，production_cutover=DENY。

## R6 降回兼容（低）

旧版本读到持久化的 `plainline` 原始值时，`VeilAppearanceSelection(rawValue:)` 失败落既有缺省（veilOriginal），不会崩溃。
