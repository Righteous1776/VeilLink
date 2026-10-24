# VeilLink RareLab · Forty Rare Offline Operators (R1)

新增 40 项独立 Foundation 运算功能、独立 SwiftUI 本地输入／运行界面、8 项 XCTest（包含 40/40 运算器示例与全量确定性复测），避免覆盖已有的 Mission Control 20 项。

**已验证**：Swift 6.2.1 Linux Foundation 编译；SwiftPM XCTest 8/8 通过，其中按 1..40 循环运行全部 40 个运算器；SwiftUI 文件通过 Swift 前端语法解析。

**未验证**：iOS SDK、SwiftUI 类型检查、iPhone 7 iOS 15.8.3、任何真实通信／密钥／数据库读写、完整应用 XCTest、IPA。

## 源码位置（投递 Governor 后方可落地）

- `VeilLink/Core/VeilRareLabEngine.swift`：纯 Foundation 引擎，不依赖 Mission Control 或已有聊天数据。
- `VeilLink/UI/VeilRareLabView.swift`：搜索 40 项、选择运算器、编辑匿名 JSON 样本、运行并读取中文输出。
- `VeilLinkTests/VeilRareLabEngineTests.swift`：8 项单测。
- `PATCH.diff`：在 `VeilLink/UI/ToolCenterView.swift` 新增 1 个工具中心入口。

所有运行都是手动触发，输入数据仅保存在当前内存，界面不会写文件、连接远程端或修改 Keychain。JSON 最大 64 KB，Graph 边界有限制；禁止粘贴实际身份密钥、令牌、秘密、真实内容。

## 功能组

A（1–10）无线与 Mesh；B（11–20）传输与恢复；C（21–30）身份与隐私；D（31–40）触控与取证。完整列表见 `FEATURE_MATRIX.md`。

## 集成顺序

先完成已有 P0 触控／数据库保护，再由 Governor 在独立集成分支选取源码及入口补丁，运行 XcodeGen／iOS 15 编译／全部 XCTest／iPhone 7 真机触控验证。现有 `main`、发布号、Wire v4、SQLite v10、A9/A10 均不修改。