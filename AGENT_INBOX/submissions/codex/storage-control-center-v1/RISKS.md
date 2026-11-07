# RISKS — storage-control-center-v1

## 风险与缓解

- **删除不可撤销**：下载和加密备份不在建议选择中，必须用户逐类勾选并再次确认；UI 明示不可撤销。
- **活跃临时文件竞争**：仅识别固定前缀且要求 24 小时老化，清理前重新计算候选并再次验证。
- **路径逃逸/符号链接**：只删除已知根目录的直接子项；扫描不跟随链接；测试覆盖外部链接目标。
- **诊断并发写入**：不由通用文件引擎删除诊断，复用 `DiagnosticLogStore.clear()` 的缓冲和文件生命周期。
- **大目录扫描成本**：文件遍历在 actor 上执行，UI 使用异步任务；集成时仍需用 1 GB/大量小文件夹具测量。
- **URLCache 并发兼容性**：需在严格并发 iOS 构建中确认 Foundation 注解；若编译器告警，应由 Governor 将 URLCache 操作封装到合适隔离域，不应放宽全局并发检查。
- **下载区暂为空**：当前产品没有正式下载写入路径。本提案定义安全目录与删除合同，但不会谎称 Bundle 内资源可删除；未来下载器必须只写该目录。

## 重叠

- `kimi-local-iteration/ui-type-scale-ranks-002`、`ui-rhythm-token-foundation-001` 与 `ui-plainline-experimental-style-001` 的历史提案均触及 `SettingsView.swift`。本提案只在 `storageCard` 开头增加 NavigationLink，不自行合并或裁决那些 UI 提案。
- 当前 main 已包含这些 Kimi 批次的大部分整合结果；若 Governor 仍计划重新应用旧 Inbox patch，应以当前 main 语义重放而不是直接叠加。
- 未发现其他现存 Inbox 提案触及存储清理引擎或相同测试文件。

## 明确不做

- 不删除聊天附件、消息、数据库、Keychain、身份或社区状态。
- 不修改数据库 schema、传输队列或协议。
- 不删除 IPA Bundle 内资源，也不声称手动清理能缩小 IPA 安装包。
- 不添加自动后台删除；首次版本保持用户可见、可确认的手动治理。
- 不改版本号、不构建 IPA、不触发 workflow、不发布或自合并。
