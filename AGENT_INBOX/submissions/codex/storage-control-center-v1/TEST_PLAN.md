# TEST PLAN — storage-control-center-v1

## 自动测试

新增 `VeilStorageMaintenanceTests`：

1. `testScanSeparatesProtectedDataFromRecoverableData`：数据库与下载分别计入受保护/可回收类别。
2. `testCleanupNeverDeletesDatabaseOrAttachments`：即使请求集合包含 `.protectedData`，数据库和加密附件也保持存在。
3. `testOnlyVeilLinkZipExportsAreCandidates`：只删除符合命名合同的 VeilLink ZIP，保留普通 ZIP 和伪装扩展名。
4. `testRecentTemporaryExportIsNotDeleted`：保留新文件，仅删除超过 24 小时且前缀匹配的临时导出。
5. `testSymlinkTargetOutsideDownloadRootIsNotTraversedOrDeleted`：链接目标不计入占用且不被删除。

## 集成验证（需要 macOS/Xcode）

1. 运行 `xcodegen generate`，确认两个新 Swift 文件自动进入 target。
2. iOS 15、iPhone 7 模拟/真机各执行一次 Debug build。
3. 运行全量 `VeilLinkTests`，并单独重复存储测试 20 次以捕获文件时间竞态。
4. 创建以下夹具后检查 UI 数字：10 MB 下载、两个 VeilLink ZIP、一个普通 ZIP、24 小时前/后的临时文件、诊断文件。
5. 同时保持录音和诊断写入，执行建议清理，确认活跃录音不被删除且日志 Store 可继续写入。
6. 清理运行缓存后打开长对话、图片预览和本地 AI，确认内容可重新加载且聊天记录未减少。
7. 开启 VoiceOver、动态字体和减少动态效果，检查行选择、删除确认和结果弹窗。
8. Instruments 检查 1 GB 下载目录扫描，确认主线程无文件遍历尖峰且页面退出后无 UI 崩溃。

## 当前已执行

- `git apply --check AGENT_INBOX/submissions/codex/storage-control-center-v1/PATCH.diff`：PASS。
- `git diff --check -- AGENT_INBOX/submissions/codex/storage-control-center-v1`：PASS。
- 当前 Linux 云环境没有 Swift/Xcode，可执行编译与 XCTest 未伪报为通过。
