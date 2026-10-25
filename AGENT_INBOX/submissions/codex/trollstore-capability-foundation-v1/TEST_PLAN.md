# TEST PLAN — trollstore-capability-foundation-v1

## 自动测试

新增十项 `VeilRuntimeEnvironmentTests`：

1. Simulator 证据拥有最高优先级。
2. TrollStore 标记覆盖残留 receipt/profile。
3. TrollStore Lite 独立识别。
4. sandbox receipt 识别为 TestFlight。
5. production receipt 识别为 App Store。
6. 只有 embedded profile 时识别为普通签名。
7. 无证据时保持 unknown，不猜测 TrollStore。
8. 后台、Bonjour 与 Live Activity 声明正确映射。
9. TrollStore 仅把增强 entitlement 标记为候选，普通签名为不可用。
10. 诊断报告不包含文件系统路径或私人内容。

新增两项 `VeilSettingsDisclosureTests`：

1. 三个折叠组的持久化 key 稳定且唯一。
2. 所有次级设置组首次默认折叠。

## 真机与打包矩阵

1. iPhone 7 / iOS 15：普通 ad-hoc 或免费签名 IPA，确认显示“普通签名安装”，全部基础功能可用。
2. 支持机型：TrollStore 与 TrollStore Lite 分别安装，确认官方 marker 被识别。
3. 将带残留 `embedded.mobileprovision` 的 IPA 通过 TrollStore 安装，确认 marker 优先且不误判为普通签名。
4. App Store/TestFlight 构建验证 receipt 分支；receipt 缺失时不得伪造来源。
5. 删除/伪造 marker 的测试夹具验证 unknown/profile fallback，不在生产包中提供伪造入口。
6. 深浅色、动态字体、VoiceOver 和 iPhone 7 小屏检查能力列表无截断。
7. 复制能力报告后验证 local-only、5 分钟过期且不含绝对路径、身份、消息、密钥。
8. BLE、LAN、Relay、后台连续性、Live Activity 和签约流程做回归；来源识别不得改变现有行为。
9. 分别展开三个设置组并重启 App，确认状态独立持久化；折叠时内部复杂卡片不在视图树中。
10. 开启“减少动态效果”后确认立即开合；关闭时确认弹簧动画无错位、闪白或重复点击抖动。
11. VoiceOver 朗读分组名称、已展开/已折叠状态及操作提示；超大动态字体不截断入口。

## 当前验证

- `git apply --check AGENT_INBOX/submissions/codex/trollstore-capability-foundation-v1/PATCH.diff`：PASS。
- `git diff --check -- AGENT_INBOX/submissions/codex/trollstore-capability-foundation-v1`：PASS。
- 当前云环境没有 Swift/Xcode，因此未宣称 iOS 编译、XCTest 或真机 TrollStore 测试已通过。
