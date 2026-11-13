# PR、Constitution Gate 与 Action 最小权限协议

## main 集成

默认只能工作于隔离分支，`commit/push` 不等于已进入共享 main。需要集成时通过 PR；Draft 反复修改与本地校验，最终 Ready for review，得到所需审查和 required checks 后合并。Ready 后不要随意改 head；必须改时先撤回 Draft 再验证。任何 CI 是否触发、触发多少次，取决于实际仓库配置；不得承诺特定次数。

## Constitution Gate 的最低职责

核对 Seal/Current Epoch、Mandatory Read ACK、Session Task-ID/branch/last verified commit、受保护路径、工作群 P0/P1/WORK_REPORT 和关键锁。Git Hook/CLI 仅本地预检；如果需要真正防绕过，应在 Git 服务端配置 branch protection/rulesets/CODEOWNERS/required checks。不要在未经 Owner 授权下直接改 rulesets。

## Actions 的角色

CI Runner 是确定性执行资源，不是智能决策主体。可申请大规模确定性处理、全仓一致性、可复现回归、标准 Artifact；通常不为了单个低成本文件编辑申请。默认 `NONE`，允许状态为 `ELIGIBLE_TO_APPLY`、`GRANTED_SCOPED`、`SUSPENDED`、`REVOKED`，只有 ACTIVE/GRANTED_SCOPED 且范围相符可运行。

申请必须列出 task/profile、workflow、必要性、输入、输出、执行成本与次数、到期、secrets/写入范围、锁要求、替代方案、授权者。单个授权不能被其他 Agent/任务共享，不能以 run Actions 顺便获得 main 或部署权限。

## 秘钥、外部服务

不可将 secrets、API Key、私人信息写进 repo/Inbox；发送仅限脱敏说明与访问控制配置。任何付费 API、部署、对外发布、第三方数据删除均依项目 Owner 明确授权；GitHub 操作权限和伦理/政策约束均仍有效。
