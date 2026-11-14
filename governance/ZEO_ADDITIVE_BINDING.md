# VeilLink · ZeoStudio 增量绑定

方案作者：久野零 / ZeoStudio。Owner 于 2026-11-13 授权此前审查的治理初始化，并补充：

> 授权，注意，我的skill也是从我几个库中提纯优化的，我库里原本有的保留，只增加新的内容

此授权仅用于本次治理迁移分支与 Draft PR；不是新的 Governor 身份、产品修改或 main 自合并许可。

## 原制度保留

所有迁移基线 `eb487a1901c0ffddfb38b80b9fb56f6d7d749ba0` 已有文件保留原 Git 对象和模式。尤其保留 AGENTS.md、Governor 身份/权限、Issue #6、QUEUE、Asset Grant、五文件模板、全部旧提案和现有 CI。此文以新增形式连接扩展；不宣告原制度作废。

权力链仍为 Owner → Integration Governor `VEILLINK-IG-001` → Lane。新增 B 文档中的多 Governor、AUTO_GREEN、工作区和分支示例仅为通用机制；不能覆盖现行 INBOX_ONLY、`agent-drop/<agent>/<task>`、protected surfaces 和集成约束。B Registry 空数组只表示未授予任何任务绑定的 Exchange 派单能力，不撤销原 Governor。

## 生效与版本

这是新增 B 命名空间的首次 Epoch 1，版本 `VEILLINK-ZEO-ADDITIVE-V1`；不存在被提升或覆盖的旧 B Epoch。Seal 的 `PENDING_MAIN_INTEGRATION` 表示引导候选：只有 Owner/Governor 审查后，通过独立流程将本增量纳入可信默认分支，普通 Lane 才可把它当作现行基线。无需为生效而修改原文件或将模板状态伪写为已发布。候选分支测试通过只证明候选，不证明 main 学习门已通过。

## 双学习门与历史兼容

新会话首先按原 AGENTS.md 和 Issue #6核对身份；然后读本绑定、B Seal/Read Set、C 07 的十一份原文。B 记录真实 ACK，C 固定 Git 对象 hash 并运行 study_gate。二者各自留证，不互相替代。

既有提案及其五文件格式不重写、不追补虚假学证、不被重新判为违规。新增提交使用原五文件再附 STUDY_RECORD.json。历史提案后续进入新集成流程时，由实际执行集成的 Agent 在当时可信基线上重新学习，历史作者不被伪装成已经学习。

现有 `.github/workflows/agent-inbox-gate.yml` 继续执行原规则。新增独立检查验证扩展，并对生效后新建的 agent-drop 提案追加学习门；对旧提案保留原 CI，不进行批量重验。独立检查不声明已经配置 required check 或分支保护。

## 写权限和消息

普通 Lane 仍只能写自己的提案根。B CLI 的 init/ack/handoff 可写共享 Session，Exchange 的 send/reply/receipt/digest 可写消息或导航；命令可用不等于授权。普通 Lane 在自己的提案 FILES 中准备 Session/Handoff 或消息草稿，由已授权 Owner/Governor/Relay 持久化到正式目录。scan/read/validate 可只读运行。本次迁移不指定新 Relay、不发布伪造收件回执。

Task Market/Index 新空数组不代表旧任务为空；旧 Session/提案/Issue 优先核对，不能重复认领。学习门 PASS 不授予 release、workflow_dispatch、shared write 或 self-merge。

## 记忆与冲突

记忆工具使用 Python 标准库与本地 SQLite；实际记忆保存在仓库外的私有路径。M07 睡眠摘要只能是候选，不能晋升为法源；没有后台计划。工具参数 `--confirmed`/`--by` 是操作人声明，不能认证身份。本次不创建真实记忆数据库。

原规则与新增机制发生冲突时，保留原规则并将冲突范围 HOLD，记录双方路径交 Owner/Governor 处理。CLI 和分支名从不成为身份凭证。

## 安装范围

本次引入可运行的 B/C 核心与 V1.5 记忆工具，并保存官方来源、SHA-256 和必要桥接原文；不是完整通用 Skill 包的镜像。未安装的跨平台提示卡、全部专题手册和上游测试套件不得宣称已安装。入口为 `.agents/skills/veillink-zeo-additive/SKILL.md`，使用实际已安装路径。
