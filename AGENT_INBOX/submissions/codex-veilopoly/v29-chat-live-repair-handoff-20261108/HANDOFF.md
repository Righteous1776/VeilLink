# 给下一代理：只从这里续接

## 0. 当前指令

Owner 最新要求：“将你现在的成果提交到inbox，我找其他的代理来做”。
当前代理到投递结束即停止。不要继承一个虚构后台任务，也不要认为正式V29已经发布。

## 1. 最快接管路径

1. 获取最新main并学习仓库治理；记录是否仍为2c5b516。
2. 读取完整受测树27c6801385409399bd0ffffa42a397b7222e8a3f（远端分支 integration/v29-veilopoly-candidate-fix-20261108）。不要重复盲合旧Inbox/替代棋类分支。
3. 看PR182和Apple CI42431674523；已全绿，但物理双机待验收。
4. 给Owner同一份新候选做 TEST_PLAN 的聊天邀请/新V5房间复测。Owner要求正式版时，再做正常受控合并与不可覆盖的正式发布。

## 2. 不要拿错包

**正确修复候选：** https://github.com/Righteous1776/VeilLink/actions/runs/42431674523/artifacts/13597897677

所有候选仍可能显示29.0/build66，必须以 run42431674523 / source27c6801 / artifact13597897677 区分。
旧 artifact13586091649（run42401910361）、13587622673（run42403714966）是修复前，不得当修复包。
新IPA散列、尺寸和自动化证据见TEST_PLAN.md；未签名。

## 3. 分支及断点

- main：2c5b5161027edff097b27fe3323d30f6ca3e430e，仍V28基线。
- integration/v29-unified-20261107：7ecdccedc7833a073217c5a142bb1c19d9cbf2dc，PR181 draft；整合了功能但有本轮发现缺陷。
- integration/v29-veilopoly-candidate-fix-20261108：27c6801385409399bd0ffffa42a397b7222e8a3f，PR182 draft → 前一集成分支。
- 修复提交：5455271 → ff3ce12 → 27c6801。无main merge、tag或正式Release。
- validation/v29-verified-promotion-20261107：572bdb7，发布job禁用；旧脚本绑定旧run/head，**不能直接重新打开即发版**。
- 下一项唯一任务：复测当前聊天邀请与新V5联机，然后按最新Owner决定走正式集成；不要先扩展新功能。

## 4. 两套补丁怎么用

PATCH.diff：相对当前可信main的完整文本投影，含V29全部文本整合。唯一模型二进制从声明来源取得，不能靠文本补丁凭空出现。
REPAIR_ONLY.diff：已经具备7ecdcced完整V29树时，应用本轮10文件增量；它不是主线补丁。
推荐审核实际27c6801源树，而非重新拼接；从那里读取 docs/engineering/V29_CANDIDATE_HOLD_20261108.md 的8步手机验收。

## 5. 已有协调回执

- #168： https://github.com/Righteous1776/VeilLink/issues/168#issuecomment-6715276935
- #6： https://github.com/Righteous1776/VeilLink/issues/6#issuecomment-6715329003
- PR181暂停： https://github.com/Righteous1776/VeilLink/pull/181#issuecomment-6715285624
- PR182最终CI回执： https://github.com/Righteous1776/VeilLink/pull/182#issuecomment-6715462058

不要把机器绿灯、源码修复、双机接受和正式发布混为一个状态。
