# agent_exchange.py — CLI 命令手册（Python 3.10+）

所有命令都在目标仓库根目录运行；如果脚本安装在 `tools/governance/`，默认自动识别仓库根目录。执行 `python tools/governance/agent_exchange.py --help` 查阅完整参数。

## 发送普通通知

```bash
python tools/governance/agent_exchange.py send \
  --task-id TASK-BUILD-001 --session-id SESSION-001 \
  --profile ENGINEER --lane BUILD \
  --type INFO --target LANE:QUALITY \
  --priority P2 --subject '交接信息' --body '请阅读已提交的技术说明' \
  --branch agent/build/task-build-001 --commit abcdef0
```

`send` 支持 `--type INFO|REQUIRED_READ|REQUIRED_RESPONSE|BLOCKER|HANDOFF|DECISION|TASK_REQUEST|TASK_ASSIGNMENT|OWNER_DECISION_REQUIRED`。多个 `--target` 为 OR 规则。`TASK_REQUEST` 自动发给 GOVERNOR 并要求回应；`TASK_ASSIGNMENT` 需要明确收件人且至少要求阅读，但依项目治理核实发送者权力。

## 机械工作汇报

```bash
python tools/governance/agent_exchange.py report \
  --task-id TASK-BUILD-001 --session-id SESSION-001 \
  --profile ENGINEER --lane BUILD --subject '阶段交付' --body '可验证阶段汇报' \
  --completed '功能已合并至工作分支' --artifact 'workspaces/build/TASK-BUILD-001/result.txt' \
  --not-done '未进行生产发布' --downstream-read '复核 result.txt' \
  --target PROFILE:REVIEWER --next-recommendation '执行独立审阅'
```

## 扫描 Inbox

```bash
python tools/governance/agent_exchange.py scan \
  --task-id TASK-REVIEW-002 --profile REVIEWER --lane QUALITY
```

输出每个 pending `message_id/priority/delivery`，最后固定输出 `PENDING_REQUIRED`、`INFO_MATCHED`、`BLOCKING`。存在 P0/P1 未完成必读时退出码为 `3`，否则为 `0`。`--json` 输出结构化 JSON；`--show-info` 显示普通消息摘要； `read --message-id <ID>` 打印全文。

## 回执

```bash
python tools/governance/agent_exchange.py receipt \
  --message-id MSG-... --task-id TASK-REVIEW-002 --session-id SESSION-002 \
  --profile REVIEWER --lane QUALITY --status READ --note '全文已读'
```

回复要求：**先 reply，后 receipt**：

```bash
python tools/governance/agent_exchange.py reply \
  --in-reply-to MSG-ORIGINAL --task-id TASK-REVIEW-002 --session-id SESSION-002 \
  --profile REVIEWER --lane QUALITY --subject '答复' --body '已完成确认'
# 获取打印的 MESSAGE_ID，再写状态 RESPONDED，并指定 --response-message-id
python tools/governance/agent_exchange.py receipt ... --status RESPONDED --response-message-id MSG-REPLY
```

## 摘要与验证

```bash
python tools/governance/agent_exchange.py digest
python tools/governance/agent_exchange.py validate
```

`digest` 是当前数据快照的导航，`validate` 检查目录内消息和回执的一致性，并不能代替 Git remote 权限和跨电脑传输验证。

## 常见错误

`MESSAGE_NOT_FOUND`：需确认是否 fetch 了消息所在分支。`MESSAGE_NOT_ADDRESSED_TO_RECIPIENT`：不得替别人确认。`REPLY_REQUIRED`：要回复不能直接写 RESPONDED。`BAD_RESPONSE_REFERENCE`：reply ID 不正确。`MESSAGE_ALREADY_EXISTS`：不可覆盖旧消息。`INVALID_SCHEMA`：检查 JSON 字段或版本。
