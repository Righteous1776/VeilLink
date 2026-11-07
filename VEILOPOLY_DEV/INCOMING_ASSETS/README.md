# Kimi 入库缓冲区

此路径仅放经 Owner 转交、ChatGPT 验证并明确允许入库的 Kimi 资源和 manifest。

- Kimi 无 GitHub 直写权限，提交 ZIP/增量包给 Owner。
- ChatGPT 逐项检查文件名、别名、SHA-256、bytes、license、sources 与可用性后迁入此分支。
- 原始交付包禁止直接以大 ZIP 留在 repo；应解压，清理重复、选择可用导出，保留来源。
- 合并进 `Veilopoly/Sources/VeilopolyUI/Resources/` 前，需验证 Swift Package 资源引用、手机/平板适配、快速跳过动画的完成回执。
- 禁止修改 main、AGENT_INBOX、VeilLink 传输层与数据库。
