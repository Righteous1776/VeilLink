# COMPATIBILITY PLAN — Wire v5 / Database v9

本文件是后续受保护变更的设计输入，不属于本补丁的产品改动。

## 协议升级原则

当前安全握手为 Wire v4，收到不同版本会直接拒绝。为了避免 v5 设备与现有 v4 用户彻底断联，建议：

1. 保持 v4 Hello、签名域 `VeilLink/Hello/v4` 和密钥派生 transcript 不变，先建立现有安全会话。
2. 在已认证加密通道内增加 `CapabilitiesV1` 控制消息，声明功能位、最大附件能力、可选帧版本和安装档位；安装档位只参与性能选择，不参与身份信任。
3. 未收到 capability advertisement 时按纯 v4 对端处理；未知功能位必须忽略。
4. 只有双方都声明同一功能且本机 capability probe 通过时才启用增强帧。
5. v5 增强帧必须拥有独立大小限制、重放语义、fuzz corpus 和 downgrade 测试；不能用 TrollStore 身份绕过加密、配对或信任。
6. 真正提升外层 envelope 版本前，至少保留一个版本周期的 v4 fallback，并记录明确的协商失败原因。

## 数据库 v9 建议

当前数据库迁移到 schema version 8。建议 v9 只增加可回滚的协商状态，不移动或重加密消息正文：

- `peer_capabilities(local_identity_id, peer_identity_id, protocol_floor, protocol_ceiling, feature_bits, observed_at, expires_at)`；
- 主键按本地身份与对端身份隔离；
- capability 记录设过期时间，不能永久信任旧探测；
- 启动迁移使用事务和 `CREATE TABLE IF NOT EXISTS`，完成后才写入 migration 9；
- 旧版回滚时新增表可以保留但不影响 v8 查询；
- 备份导出必须明确是否包含协商缓存，默认可不包含。

## 禁止耦合

- 不把 TrollStore 标记写入联系人信任、身份密钥或配对码；
- 不因安装来源降低消息验证、重放保护或附件大小检查；
- 不让数据库迁移依赖 TrollStore，所有安装渠道使用同一可恢复 schema；
- 不在能力协商中发送 entitlement 原文、文件路径或设备唯一标识。

## 进入实现前的门槛

- Governor 明确批准协议/schema live lane；
- v4↔v4、v4↔v5、v5↔v5 兼容矩阵完整；
- 数据库 v8→v9、重复迁移、中断恢复、损坏回滚测试通过；
- iPhone 7、普通侧载、TrollStore、TrollStore Lite 四类真机结果有记录；
- 安全审查确认增强权限不会扩展聊天明文或密钥暴露面。
