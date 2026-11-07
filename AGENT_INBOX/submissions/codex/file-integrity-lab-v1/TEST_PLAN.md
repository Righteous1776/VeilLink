# TEST_PLAN — file-integrity-lab-v1

## 自动化

1. `git apply --check PATCH.diff`：补丁能无冲突应用到 `8048b5c52b87eeb5d3622582da5728a8c2d64dda`。
2. `VeilFileIntegrityEngineTests.testKnownSHA256AndExactByteCount`：验证 `hello` 的标准 SHA-256 与 5 字节计数。
3. `testEmptyFileUsesStandardDigest`：验证空文件标准摘要。
4. `testComparisonChecksSizeAndDigest`：使用 `512 KiB + 17` 字节跨块负载，验证相同和不同内容。
5. `testReportContainsNamesSizesAndHashesButNoPaths`：验证报告有必要信息但无沙箱绝对路径。
6. `testDirectoryIsRejected`：目录不得被当作普通文件读取。
7. macOS CI：XcodeGen、iOS 15 Simulator build、全量 XCTest、CI evidence upload。

## 真机验收

- iPhone 7 / iOS 15：分别从“在我的 iPhone”和 iCloud Drive 选择小文件与 100 MiB 以上文件；确认页面可响应、内存不随文件等量增长、可取消退出。
- 新设备：选择两份同内容不同文件名文件，必须显示“校验一致”；修改一个字节后必须显示“不一致”。
- Day/Night、Plainline、Islet、Apple Soft：文字与哈希可读，按钮不被装饰层遮挡。
- VoiceOver：文件槽位、读取中状态和最终结论可读。

## 当前证据

- base SHA 与 `main` 一致：PASS。
- `git apply --check`: PASS。
- 提案文件范围审查：仅 4 个声明产品文件，无二进制、无资源、无 workflow/version/protected-surface 变更。
- 当前 Linux worker 无 `xcrun`/Swift toolchain，因此未声称 iOS 编译或 XCTest 已通过。
