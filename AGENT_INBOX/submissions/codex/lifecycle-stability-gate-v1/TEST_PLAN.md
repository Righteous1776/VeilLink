# TEST PLAN — lifecycle-stability-gate-v1

## 自动测试

新增七项 `VeilLifecycleStabilityGateTests`：

1. 首次 active 根视图依次挂接、启动、标记前台并进入前台；重复出现和重复 active 均无动作。
2. 正常 active → inactive → background → active 的动作及顺序保持稳定。
3. active 直接跳 background 时自动补发后台准备。
4. 重复 inactive/background 通知被忽略。
5. 内存警告突发被合并，冷却期后恢复处理。
6. 运行时启动前和非法 uptime 的内存警告被安全忽略。
7. 根视图前先收到 ScenePhase 时不启动运行时，根视图出现后按最新状态正确补齐。

## macOS / iOS 集成验证

1. `xcodegen generate` 后执行 iOS 15 Simulator build 和全量 XCTest。
2. 在 iPhone 7 上连续执行 100 次前台/后台、锁屏/解锁和控制中心打断，观察 BLE/LAN/Relay 连接恢复。
3. 用 Instruments/OSLog 核对每个真实转换只出现一次 `scene.*` 记录，Root 重绘不产生第二次 attach/start。
4. 通过 Xcode 连续发送三次 Memory Warning，确认两秒内只执行一次昂贵清理；三秒后再次发送可正常清理。
5. 在压力测试运行时切到 inactive/background，确认 pause/resume 行为与主线一致。
6. iOS 16.1+ 验证 Live Activity：inactive 阶段创建，background 阶段更新，返回 active 后继续工作。
7. 撤回/重新签署协议、切换身份和恢复备份后回归，确认不会因闸门保留旧 AppModel 状态。

## 当前验证

- `git apply --check AGENT_INBOX/submissions/codex/lifecycle-stability-gate-v1/PATCH.diff`：PASS。
- `git diff --check -- AGENT_INBOX/submissions/codex/lifecycle-stability-gate-v1`：PASS。
- 云环境没有 Swift/Xcode 可执行文件，未把静态检查冒充为 iOS 编译通过。
