# 数据与交付基本法 — 通用版

## 权威真相

每个项目必须自行声明唯一或明确定义的正式数据源（数据库、文件、对象存储等）。Git main 通常是稳定可共享快照，但**不意味着所有业务都应强制 SQLite**。生成报告、导出、缓存与摘要是派生物，不能仅因时间较新而覆盖权威事实。所有影响后续任务的变更须写 durable provenance。

## 共享写入

共享状态写之前：①确认作用域与授权；②读取最新 baseline；③获得对应跨机器有效 Lock/Lease（如需要）；④校验修改前置条件；⑤写入/commit；⑥验证后置条件；⑦写 Handoff/Session 与 Exchange 报告；⑧按授权释放锁。

对单个二进制数据库或其他不可自动合并的共享资产，设置 **single-writer**；遇到 stale 副本优先在最新基线上重放**经核对的逻辑 mutation**，不得直接二进制 merge。所有重复尝试必须有幂等键或检查 commit，防止重复副作用。工具不得把本地文件锁宣称为 GitHub 级分布式 Lease。

## 交付与恢复

交付记录：唯一 artifact path、hash/commit、版本/状态、QA evidence、失败未做、依赖、下一步；阶段完成保存 Session/Handoff，Task 完成需最新 WORK_REPORT。未真实提交或不可查询的状态要标记 `PERSISTENCE_REQUIRED`。

## 危险动作

保护 secrets、token、个人隐私、外部费用、删除、部署、发布；默认拒绝未经授权的高风险写入；先 dry-run 和最小范围测试。重要事故要回滚路径与防复发 guard。
