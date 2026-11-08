# RISKS — trollstore-capability-foundation-v1

## 风险与缓解

- **来源伪造**：容器 marker 是安装来源证据，不是安全信任根；绝不用于身份认证、密钥、配对或协议授权。
- **TrollStore 版本差异**：同时支持官方 `_TrollStore` 与 `_TrollStoreLite`；未知未来 marker 回退为 unknown，而不是猜测。
- **权限误判**：Info.plist 只能证明声明，不能证明系统已经允许；UI 明确使用“已声明”，高权限保持“待验证”。
- **沙盒扩大**：本阶段不新增 entitlement、不访问沙盒外路径、不使用私有 API。后续模块必须最小授权。
- **普通签名回归**：检测失败只影响标签，基础聊天、BLE、LAN、Relay 和数据库不依赖检测结果。
- **隐私泄露**：诊断不输出 bundle/container 路径、receipt 内容、provision 内容、身份或消息。
- **协议降级攻击**：未来 capability negotiation 只能发生在 v4 已认证加密通道内；安装来源不能降低密码学检查。
- **数据库不可逆迁移**：v9 设计为新增缓存表，不移动正文；仍需事务、中断恢复、重复迁移和旧版回滚验证。
- **设置项可发现性**：折叠降低首屏长度但增加一次点击；每组副标题完整列出内容，身份与安全保持直接显示，展开状态会记忆。
- **动画与低端设备**：只动画三组容器的 opacity/offset，不做模糊或持续动画；“减少动态效果”下完全跳过动画，需在 iPhone 7 验证布局峰值。

## 重叠

- 修改 `SettingsView.swift`，与开放 PR #50 的存储入口存在文件级重叠；Governor 应先整合存储卡片，再把最终卡片放入“外观与数据”折叠组。
- 未来协议计划涉及 `SessionCoordinator.swift`，数据库计划涉及 `DatabaseStore.swift`，均属于受保护表面；本补丁没有修改它们。
- 不与 PR #52 的会话工具逻辑重叠，但都新增设置/聊天可达功能，集成时应统一信息架构。

## 明确不做

- 不请求 platform-application、no-container、dynamic-codesigning 或其他私有 entitlement。
- 不绕过 iOS 沙盒、签名、权限提示或系统隐私控制。
- 不读取其他 App 数据，不提供任意系统文件浏览。
- 不修改 Wire v4、数据库 v8、身份/密钥、A9/A10、版本号、workflow、签名或发布。
- 不自动开启实验功能，不因 TrollStore 来源提升信任等级。
