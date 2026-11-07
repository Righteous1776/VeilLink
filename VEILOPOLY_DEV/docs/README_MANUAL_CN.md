# Veilopoly 完整规则说明书 · 编订依据

- 版本：VEILOPOLY-MANUAL-CN-V1-20261108
- 源码冻结基线：0ef5b71d1027470e40867040c4c98432d7c841f2
- 产品状态：独立研发分支；**不是已签名、已上架或已通过真机验收的正式版本**。
- 数据主稿：\`manual_canonical.json\`（13章、162条、每条独立 id/标题/副标题/正文数组/源码依据）。
- 人工阅读：\`Veilopoly_完整规则说明书_20261108.md\`，包含全部正文、40格地块及32张卡牌的独立条目。
- App 入口：\`VeilopolyGuideSheet\` → \`VeilopolyCompleteManualView\`，全文来源 \`VeilopolyCompleteManual.swift\`，支持章节过滤及全文中文搜索，严格只读。
- 配套 PDF：\`Veilopoly_城市玩家完整说明书_V5_20261108.pdf\`，A4 54页；已在当前对话交付为单独文件。该 PDF 未上传到仓库（避免未经审核的二进制资源进入研发分支）。
- 一致性约束：修改某条正文时，同时更新 JSON、Markdown、Swift 和 PDF；不要只修改 SwiftUI 标题，也不要将 V5 金额套入 V3/V4 对局。
- 内容边界：按源代码明确区分经典、V3、V4、V5 与双机经典房间；经济平衡和设备性能未经充分实验，不许宣称已稳定。

## 静态校验

编辑数据条目数 = 162；章节 = 13；地块逐格 = 40；卡牌逐张 = 32。
说明书新源码已使用 Swift 前端 parser 检查；完整 SwiftPM、Apple SDK、真机 / 两机验收 **NOT_RUN**。

## 原始生成校验（对话发布版）

\`\`\`
Markdown SHA256: 9caa9968449958fb932b41c45ef88b62840d4417f9cf6b01beabcf815079f922
Swift SHA256:    e803ad6bb74fc885a8603e3999601b3f3b90665b503fc45e2ed3b1aa62e9864e
\`\`\`
