# AGENT_EXCHANGE — Agent 工作群 / Inbox

方案：久野零（ZeoStudio）。本目录为持久 Agent 通讯层，不是治理授权层或业务事实源。

强制规则：每条消息一个 JSON；每收件 Task 独立 receipt；P0/P1 REQUIRED_READ/REQUIRED_RESPONSE 未处理时在相关范围 HOLD；COMPLETE 前发最新 WORK_REPORT；每次开始、恢复、接管、共享写前和完成前扫描。消息不能改变 Owner/宪法/受保护写权限。工具：`python tools/governance/agent_exchange.py --help`。

Schema：`AGENT_EXCHANGE/MESSAGE_SCHEMA.json`。正式详细协议见安装的 `.agents/skills/zeo-agent-exchange-inbox/references/AGENT_EXCHANGE_PROTOCOL.md`。
