# Feature implementation matrix (new domain algorithms)

| ID | Capability | Implemented computation | Contract / boundary |
|---|---|---|---|
| MC-01 | 链路健康评分 | RSSI + 丢包率 + 延迟加权 | 正常/警告/阻断 |
| MC-02 | BLE/LAN 路径决策 | 选出当前能力允许的推荐路径 | 不自动切换真实传输 |
| MC-03 | Mesh 最优路径 | 有限图 Dijkstra 加权路径规划 | 有界图且不代表已认证 |
| MC-04 | 独立备用路径 | 排除主路内部节点重算 | 不能保证无线频段独立 |
| MC-05 | 中继跳数预算 | TTL/hop 范围校验 | 超出预算拒绝候选 |
| MC-06 | MTU 安全分片 | ATT MTU 减去3字节的理论载荷 | Wire开销需再扣减 |
| MC-07 | 断点恢复计划 | 已确认字节及剩余长度 | 必须重新核验认证检查点 |
| MC-08 | 拥塞窗口控制 | AIMD 加1 / 丢包减半 | 纯建议，绝不改实际队列 |
| MC-09 | 自适应重试 | 指数退避并封顶60秒 | 不绕过iOS后台限制 |
| MC-10 | 控制消息优先级 | 队列深度计算控制流预留槽位 | 保证数据业务仍有机会 |
| MC-11 | 交付可靠性 SLO | 最近交付延迟P95 + 未送达数量 | 避免小样本保证 |
| MC-12 | 存储空间预测 | 可用空间/日增量估算天数 | 只读，绝不清理数据 |
| MC-13 | 密钥与数据库保护门禁 | 文件存在、受保护数据、密钥访问三阶段 | fail-closed且不重建密钥 |
| MC-14 | 重放异常检查 | 重复计数/逆序计数 | 不替代协议重放防护 |
| MC-15 | 遥测隐私风险 | 敏感元数据+原始触摸记录检查 | 不输出隐私内容 |
| MC-16 | 热负载保护 | nominal/fair/serious/critical预算 | 不改变A9/A10治理 |
| MC-17 | 电量续航保护 | 低电量与节能模式建议 | 不保证后台常驻 |
| MC-18 | 触控覆盖检查 | 可见装饰层命中识别风险 | 需要iOS真机验证 |
| MC-19 | 故障事件关联 | 最高频错误及总计数 | 不声称相关即因果 |
| MC-20 | 能力降级协商 | 期望能力与可用能力取差集 | 不伪造系统权限 |

Each listed capability has a dedicated `case` in the pure engine, a title/group and a report branch. There is one shared SwiftUI rendering surface; these are computed capabilities, not twenty separate native screens or twenty real system integrations.
