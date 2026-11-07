# RISKS — adaptive-particle-system-v1

## 风险与缓解

- **全局 GPU/电量成本**：自动预算最高 30 FPS/22 环境粒子；低电量、旧设备、严重温控和后台立即关闭。
- **老设备强制过载**：只有现有上帝模式显式 full visual override 才能绕过自动限制；persistent 仍需第二个独立开关。UI 已有热力学风险文案。
- **辅助功能冲突**：Reduce Motion 默认权威关闭；上帝模式覆盖属于用户明确的开发者选择，测试必须覆盖退出上帝模式后的即时恢复。
- **手势冲突**：使用 simultaneous gesture 和无命中 Canvas；仍需验证系统返回手势、ScrollView、文本选择与实时游戏。
- **粒子遮挡**：低 alpha、小尺寸、plus-lighter 混合；不在布局树占空间，不传达唯一信息。
- **状态更新延迟**：Root 观察 `PerformanceOverrideController`，电量和温控通知驱动重新计算；未知 thermal 状态保守按 serious 处理。
- **内存增长**：拖尾数组按档位最多 8/12/18 个采样，粒子由 Canvas 即时计算，不创建持久 View 或纹理。
- **异步 Canvas 一致性**：输入均为值快照，伪随机位置确定；需要 iOS 15 真机验证异步 Canvas 不出现闪烁。

## 重叠

- 修改 `VeilLinkApp.swift`，与开放 PR #51 生命周期稳定闸门存在文件级重叠；Governor 应先整合生命周期协调器，再把粒子 modifier 放在最终 RootContainer ZStack 与 HUD 之间。
- 新策略读取现有 PerformanceOverride 和 VeilRenderProfile，不修改 PR #51 或现有上帝模式语义。
- 游戏已有独立 SpriteKit/Canvas 粒子；全局层粒子密度较低，但实时游戏页面需评估是否按路由暂停全局环境粒子。

## 明确不做

- 不修改 Owner capability、A9/A10、游戏渲染器或现有性能覆盖权限。
- 不保存触点、屏幕路径或用户行为分析。
- 不添加 Metal shader、第三方粒子库、图片资产或网络资源。
- 不修改数据库、协议、身份、签名、版本、workflow 或发布。
- 不自合并。
