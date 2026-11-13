# VeilLink · ZeoStudio 增量核心

先读 [增量绑定](../ZEO_ADDITIVE_BINDING.md) 和仓库现行 AGENTS.md。方案作者：久野零 / ZeoStudio。入口版本 1.5.0；本目录是适配后的核心集成，不是完整通用包。

本次仅新增文件；已有同名功能和原始规则均保留。SOURCE_LOCK.json 记录每个引入文件的上游资源、原始 SHA-256、安装后 SHA-256，以及是否为项目适配。上游原文中的未安装相对路径不能视为可用能力。

## 开始与验证

```sh
# 只读探测
python3 tools/governance/governance_cli.py --help
python3 tools/governance/agent_exchange.py scan --task-id YOUR-TASK --profile ENGINEER --lane YOUR-LANE
python3 tools/governance/agent_exchange.py validate

# 新提案：先读十一份真实法源并生成自己的学证，再运行
python3 AGENT_INBOX/tools/study_gate.py --repo . --record AGENT_INBOX/submissions/your-agent/your-task/STUDY_RECORD.json
python3 AGENT_INBOX/tools/inbox_gate.py --repo . --local --submission AGENT_INBOX/submissions/your-agent/your-task

# 回归测试只使用临时合成仓库，不修改真实提案或记忆
python3 -m unittest discover -s tools/governance/tests -v
```

如果新法源还没进入 main，正式 study_gate 应当失败。测试候选时可以显式 `--reference <candidate-sha>`，但报告必须写“候选验证”，不能当作 main PASS。B init/ack/handoff 会修改 Session；只有经授权的共享写者才运行，Lane 默认在提案中准备草稿。原 main 的治理文件不被替换。

记忆工具：`python3 tools/governance/memory/zeo_memory.py --help`。实际使用时显式给 `--workspace /your/private/path`。本迁移不创建真实数据库、不保存私人聊天、不启用后台任务。README 及四份已安装参考原文在 memory 目录。

## 新旧提案

原 Agent Inbox workflow 原样保留。独立 `Zeo Foundation Checks` 执行新增组件回归，并对其可信 PR base 已包含 07 学习规则、且 base 不存在该提案 MANIFEST 的新建提案，追加 V1.2 严格校验。旧提案保持原五文件与原 CI；若以后开展新集成任务，集成执行者需完成当前双学习。

既有 admin gate 的分支命名不证明身份。本次不更改它，也不假装新增 workflow 已被设为服务端 required check。新 supplemental check 不是权限服务，主线集成仍需 Owner/Governor 审查。

## 增量不变量与回退

```sh
# 专用于本次迁移的候选 commit，后续包含产品开发的提交不要套用此迁移基线
python3 tools/governance/check_additive_migration.py --base eb487a1901c0ffddfb38b80b9fb56f6d7d749ba0 --head HEAD
```

该命令逐个核对所有基线文件的 Git blob、模式和路径，拒绝修改、删除、重命名和权限变化；并核对新增引入文件的 SOURCE_LOCK。它不证明代码功能，也不验证服务端写权限。回退通过审查后的 revert 移除新增迁移；不 reset/force-push，不清理旧提案。

当前迁移保持 Draft，main 未激活新的学习基线。接手先读本任务 Session/Handoff，核对真实 branch/commit 和 PR/CI；GitHub 状态以实际回读为准。
