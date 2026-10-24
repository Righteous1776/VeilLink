# 集成测试矩阵

- [x] Linux Swift6.2.1 + `-swift-version 5 -strict-concurrency=complete` Foundation 模块编译（模拟产品 Swift5 模式）
- [x] Linux SwiftPM XCTest 12/12；100 项循环执行两次同输出，空字典 100 项，极端数组/数字/形状 400 次不崩溃
- [x] SwiftUI 使用 `swiftc -frontend -parse` 做纯语法检查；**不等于 iOS SDK typecheck**
- [ ] Governor 选定不冲突的单一 UI 链接后，将 5 个文件应用到独立产品集成分支
- [ ] `git apply --check` 当前 main；XcodeGen + iOS15 simulator build + full XCTest
- [ ] iPhone 7 iOS15.8.3：黑暗/浅色、动态字体、VoiceOver、键盘弹出、滚动100项、输入32 KiB、后台恢复、快速点按
- [ ] BLE 协作/本地存储兼容；确认实验室不能读取实际聊天数据、Keychain 或数据库
- [ ] 特别核验 SwiftUI 100 项目录的低内存构建成本、热状态、电量及帧率
- [ ] P0 #64 #65 #66 手势/启动数据连续性检查通过以后方允许上线
- [ ] 功能区与 #67/#68 Mission Control、#70 RareLab、#69 Feature Century 和 #72 Productivity 避免同名类型/重复入口

**不允许：** 因缺少 CI 自动触发而主动 `workflow_dispatch`/IPA 发布；不许直接修改 main。
