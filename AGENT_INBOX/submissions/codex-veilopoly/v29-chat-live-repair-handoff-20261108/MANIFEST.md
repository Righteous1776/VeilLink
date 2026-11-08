# V29 / Veilopoly 接管投递

- agent_id: codex-veilopoly
- task_id: VLP-P5-CHAT-PARITY-001-HANDOFF
- anchor: ccafebab
- status: DROPPED — 待接管者审核，不代表 ACCEPTED / MERGED / RELEASED
- Owner 最新指令：停止当前代理继续开发、合并及发布；把现有成果交 Inbox，由其他代理接手。
- trusted_base_main_sha: 2c5b5161027edff097b27fe3323d30f6ca3e430e
- complete_tested_source: integration/v29-veilopoly-candidate-fix-20261108
- source_sha: 27c6801385409399bd0ffffa42a397b7222e8a3f
- prior_v29_base: 7ecdccedc7833a073217c5a142bb1c19d9cbf2dc
- PR182（修复）: https://github.com/Righteous1776/VeilLink/pull/182
- PR181（既有 V29 集成）: https://github.com/Righteous1776/VeilLink/pull/181
- 两个 PR 均 draft / unmerged；main 未合并，没有正式 v29.0-b66 Release。

## 工件边界

PATCH.diff 是相对上述最新 main 的完整 **160 个文本文件**补丁，供接管者审核全部 V29 成果。
唯一新增模型二进制不放入 Inbox，来源/字节/散列见 BINARY_PREREQUISITES.json。
因此 PATCH.diff 单独不是完整可构建安装包：必须具备该已授权来源模型，不能声称文本补丁单独编译通过。
REPAIR_ONLY.diff 是相对 prior_v29_base 的 **10 文件**增量修复，不能直接套用 main。
推荐直接审核并续接 source_sha 完整产品树，它含全部依赖，且是实际 CI 受测树。
五件套之外的 HANDOFF.md 是下一代理的唯一入口；不得再次盲合所有旧分支。

- PATCH.diff: 1,208,521 bytes; SHA256 1e63703b0e009319c935045ff3b5592e3dd1ae35839d9fe33ec8e0c2d1d64616
- REPAIR_ONLY.diff: 53,577 bytes; SHA256 248ceb3be9d3288961f4a331798f032a11415ef0f7e30450e94b3cc638c9cccb
- 完整文本补丁在main2c5b516上 git apply --check PASS；增量在7ecdcced独立index上 --cached --check PASS。
- 补丁保留源文件Markdown硬换行空格，不为了空白美化破坏手册字节/散列一致性。

## 验证证据

- Linux Swift6.2.1 全包378/378 PASS97.173s；定向 Net24/24 PASS；资源5/5、模型门禁7/7 PASS。
- Apple CI42431674523 SUCCESS；macOS 包378/378、iOS 宿主916/916、UI 冒烟1/1 PASS。
- 新增6项宿主桥接测试逐项通过，但使用 fake authenticated channel，不是双机实测。
- iOS Simulator / unsigned iPhoneOS 编译及实际 IPA 内容门禁 PASS；真机双手机/BLE/LAN/触控 NOT_RUN。

## 红线复核

- Relay 60s/X25519/六位互确认不改；SQLite V8/身份/密钥不改；Wire v4 不改。
- 大富翁 **应用层邀请 packet v2** 已声明，与 Wire v4/控制片编码不是一回事；旧客户端拒绝 V5 邀请，不静默降级。
- A9/A10/A13、M5 shadow / production_cutover DENY 不改；旧档不自动改价。
- 无强推、强制重置、全文件回滚、产品文件删除、源分支覆盖或签名操作。
- V29 构建配置29.0/build66 位于未合并产品树；本投递不再修改版本/工作流/产品源码。
- Inbox 不含 IPA、ZIP、模型权重、签名资料或密钥，仅文本、散列和已存在工件链接。
