# VeilLink A10 Integration Readiness — I6

## 状态
`A10_INTEGRATION_READY` / **A10 对接准备 · 个性化适配阶段**。

当前 active health kernel 仍然是 `veillink.a9.compat.v1`。I6 不包含 A10 实现，也不会提前切换 A10。

## 接口准备
- Universal Lattice Kernel host ABI：Signal Bus v1、Host Profile、Fault Domains、Decision Snapshot、Compute Budget Envelope。
- A9 输入镜像成版本化 Signal Frame；A9 决策继续是 authoritative compatibility baseline。
- A10 runtime adapter 只能拿净化后的信号，拿不到 DB handle、BLE object、游戏 mutation、密钥或 Tool Router 执行权。
- `A10_SHADOW_VALIDATION` 双跑同一 Signal Frame，累计 unexpected decision diff。
- I6 不提供 public A10 cutover API。
- 当前 A9 Compute Governor 预算镜像为通用 Budget Envelope，为 Compute Governor V2 接线准备。

## VeilLink 个性化边界
- 本地、离线优先；禁止 kernel 云调度和 peer compute offload。
- advisory-only；不得直接断链、写库、改聊天/游戏状态或读取 secrets。
- 信号域：storage / transport / system / agent / game / lifecycle。
- A9 144-state compatibility profile 保留，A10 compatibility profile 目标为 **0 unexpected decision diffs**。
- LAN/Relay/Mesh 若未来重新进入正式 source，必须经 Signal Bus 上报，不得由 kernel 直接持有传输对象。

## A10 到位后的接线顺序
1. A10 实现 `VeilLatticeKernelRuntimeAdapter`。
2. 加载 `veillink.a10.profile.v1` compiled profile。
3. 进入 `A10_SHADOW_VALIDATION`，A9 继续 active。
4. 同一 Signal Frame 双跑 A9 compatibility 与 A10 compatibility。
5. unexpected diff 必须保持 0。
6. XcodeGen / XCTest / iPhone 7 + iPhone 13 burn-in 通过。
7. 仅由正式 release/cutover 流程切换 active profile；Kernel 不能自我晋升。
