# PROPOSAL — 生命周期稳定性闸门

## 问题

当前 `VeilLinkApp` 直接在多个 SwiftUI 修饰器里启动通信、刷新前台状态、准备后台连续性和回收内存。SwiftUI 的 `onAppear` 可能重复触发，ScenePhase/UIApplication 也可能短时间发送重复状态；每次通知都会再次启动或刷新 BLE/LAN/Relay、诊断订阅、后台任务和 AI 内存路径。

这不一定立即崩溃，但会造成老设备上的任务抖动、重复网络恢复、后台窗口反复建立、压力测试状态重复切换及内存警告下的额外主线程负担。

## 方案

新增两层结构：

1. `VeilLifecycleStabilityGate`：不依赖 UIKit 的纯状态机，把噪声事件转换成确定、可测试的动作序列。
2. `VeilAppLifecycleCoordinator`：在 MainActor 上执行动作，集中连接 AppModel、诊断桥、压力测试和后台连续性中心。

关键行为：

- 同一 AppModel 的诊断挂接和 `model.start()` 每个生命周期只执行一次；
- 首次根视图出现时按真实 ScenePhase 补齐前台/后台状态，不依赖 `onChange` 是否发送初始值；
- 重复 active/inactive/background 通知不再重复执行；
- 即使系统直接从 active 跳到 background，也先准备后台连续性，再进入后台；
- BLE 的前台标记与压力测试的活跃标记始终一起变化，避免迁移时遗漏既有行为；
- 两秒内成串的内存警告只执行一次完整回收，后续真实警告仍会触发；
- AppModel 实例变化时自动重置闸门，不把旧模型状态带到新模型。

## 保持不变

- 真正的 active → inactive → background → active 顺序完整保留；
- 后台时仍锁定 App Lock 与 Owner Mode；
- 内存警告仍通知诊断、压力测试、后台连续性和 AppModel；
- 不改变 BLE/LAN/Relay 的内部算法、协议或恢复预算；
- 不降低动画质量，不修改上帝模式、游戏或渲染策略；
- 不改 A9/A10 决策权限。

## 验收标准

- 重复 Root `onAppear` 不会再次挂接或启动运行时；
- 重复 ScenePhase 不会再次刷新通信栈；
- 正常前后台往返动作顺序与现有语义一致；
- 直接 active → background 仍有后台准备；
- 内存警告 2 秒突发被合并，2 秒后的警告可再次执行；
- iOS 15 / iPhone 7 上多次锁屏、切后台、接听电话和内存压力后不出现任务泄漏或失联。
