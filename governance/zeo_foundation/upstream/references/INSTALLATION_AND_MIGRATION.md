# 安装与升级控制

## 适用范围

`tools/install_unified.py` 设计为 **一次性新仓库模板安装器**。对目标目录已有同名文件、AGENTS.md、governance、AGENT_EXCHANGE、AGENT_INBOX 任何计划写入冲突，先拒绝安装。无 Git 时可以建模板，但 C 的学习机器核验直到 Owner 建立可信 Git 基线前不能通过。

## 新仓库推荐操作

1. 建立由 Owner 控制的空目录/仓库，单独留备份；`--dry-run` 审查计划文件。
2. 指定 `--project-slug <2-31字符代码>` 与 `--owner <账户标签>`；必要时指定 `--platform`/`--with-github-gate`。
3. 运行安装器，确认生成单一 `AGENTS.md` + `.agents/skills/zeo-unified-agent-foundation/SKILL.md` 和 C 两项 Skill + B `governance/` `AGENT_EXCHANGE/` + C `AGENT_INBOX/` 与两个工具目录互不覆盖。
4. Owner 审核权限链、保护文件清单、默认分支、访问控制；手动 git commit，配置 required checks / branch protection。
5. 各 Agent 使用现行 repo 文件重新跑双学习门并开始。**不能用包内 hash 代替 repo Git 对象 hash**。

## 旧项目迁移（禁止盲装）

- 备份现有真实治理和未结 Task / Inbox / Lock 状态。
- 先比对原项目 Owner 授权、Epoch、权限、路径 Schema、当前 CI、消息与回执；列出每一冲突。
- 不合并旧消息、旧业务项目配置、密钥、实际用户数据到这份通用发布包。
- Owner 正式决定是否允许桥接协议生效、是否升 Epoch 和是否重做学习记录；不得替换现有最高宪法。
- 在测试分支验证 B 工作回执、C 提案机器门、双通道不交叉、无旧脚本自动越权；再由 Owner 通过独立流程升级。

## 不会执行的动作

本安装器不获取远程仓库、不读取私人账号、不申请 token、不推送、不修改分支保护、不发布、不开后台任务。
