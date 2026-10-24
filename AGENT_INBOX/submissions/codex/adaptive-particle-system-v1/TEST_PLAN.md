# TEST PLAN — adaptive-particle-system-v1

## 自动测试

新增十项 `VeilParticlePerformancePolicyTests`：

1. 旧合成器在自动模式关闭。
2. Reduce Motion 在自动模式关闭。
3. 低电量在自动模式关闭。
4. serious/critical 温控关闭。
5. fair 温控降到 15 FPS efficient 档。
6. modern/full 使用有界 30 FPS balanced 档。
7. 上帝模式在旧设备 + Reduce Motion + 低电量 + critical 条件下仍强制 cinematic。
8. 只开启 full visuals 不会隐式开启持续环境粒子。
9. App 非 active 时即使上帝模式也停止渲染。
10. 伪随机种子确定且严格位于 `[0, 1)`。

## 真机与 UI 验证

1. iPhone 7 / iOS 15 自动模式运行 10 分钟：确认 Timeline 未创建、CPU/GPU 无新增持续占用。
2. iPhone 7 上帝模式：分别测试仅 full visuals 与 full + persistent；确认前者只有拖尾/爆发，后者有完整环境粒子。
3. 现代设备滚动设置、聊天和工具页：确认拖尾不抢 ScrollView、按钮、文本选择或返回手势。
4. 切换签约、身份、锁屏和主分区，确认一次分解爆发且没有重复触发。
5. 连续拖拽 5 分钟，确认 trail 数组不超过预算、内存不增长、离屏碎片自动消失。
6. 切换深色/浅色/Plainline/Islet/Apple Soft，确认颜色可见但不压低正文对比度。
7. 开关 Low Power、模拟 thermal fair/serious、切前后台，确认预算即时切换且后台无 Timeline 更新。
8. VoiceOver、Reduce Motion、动态字体和压力测试 HUD 回归。
9. Instruments 测量 modern 30 FPS 与 God 60 FPS 的 CPU/GPU/功耗；出现掉帧时按粒子数而不是降低交互帧率。
10. 全量 XCTest、iOS 15 Simulator build、iPhone 7 与至少一台现代设备 smoke test。

## 当前验证

- `git apply --check AGENT_INBOX/submissions/codex/adaptive-particle-system-v1/PATCH.diff`：PASS。
- `git diff --check -- AGENT_INBOX/submissions/codex/adaptive-particle-system-v1`：PASS。
- 当前云环境没有 Swift/Xcode，因此未宣称 iOS 编译、XCTest、Instruments 或真机帧率已通过。
