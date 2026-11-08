# Veilopoly 完整说明书 · 编写与 PDF 出版规格

文档编号 `VLP-MANUAL-V5-R1`。唯一权威的可编辑 Markdown 来源是 `docs/PLAYER_MANUAL_V5.md`，与 `Sources/VeilopolyUI/Resources/VeilopolyCompleteManual.md` 应**逐字节一致**。不得从旧 `VeilopolyGuideLibrary` 的经典数字重新生成 V5 说明书。更改任一金额、卡牌或版本边界，必须重新核对实际规则文件后同步更新两个 Markdown、离线 SwiftUI 阅读器测试与 PDF。

## 源码完整性

- Git blob SHA-1（含末尾换行）：`b86fa641273fae48824c7251603cfeed3821ecbb`
- Markdown SHA-256：`abae12367bc58bd89e44727ed81a531f9da4cf39cdbc03a949d7c5774c8383f6`
- 应有章节：27 个 `##` 顶级章节，另有一段版本导语；游戏说明界面解析后共 28 个显示节。
- 40 格棋盘编号：0—39，均应可按索引检索。
- 32 张卡牌：机会 0—15；命运 16—31。必须保留 V5 生效金额与 V4 兼容说明。
- PDF 版面可将章节 `##` 改为 LaTeX `chapter`，但不得改变章节正文、规则内容和数字。
- 版本、金额和技术边界以实际目标 Git SHA 为准，不能默默挪用旧文案。

## PDF 字体与出版

使用 Pandoc + XeLaTeX 生成 A4 可选取文字 PDF。正文建议使用 Noto Serif CJK SC 或 Noto Sans CJK SC，章标题深青绿、细金线，边距约 20mm，目录中文，页面页码及开发版本号需清晰。大表格必须跨页时保留列标题，不能裁剪棋盘或卡牌编号。PNG 截图不是正文的替代品，PDF 必须能够全文检索。

本次用户可下载的 2026-11-08 PDF 共 32 页；SHA-256：
`b0cf30d07178678a85bd31a37ddce7510ada4f0af48d017ba60de7269556b00c`。

**PDF 不被视为 IPA 资产。** 目前作为对话交付物发给 Owner，Git 仓库只保存可编辑 Markdown 和阅读 UI 源码。将 PDF 直接嵌入 IPA 是另一项需要独立授权、二进制资源检查和 Xcode 构建的工作。

## 允许声明的证据

- GitHub 已提交：说明书 Markdown、Bundled 资源、UI 阅读器、测试源、审计记录。
- SHA 一致性：源码级已核对，与用户下载 PDF 的 Markdown 原稿一致。
- 实际 Swift Package 编译：**NOT_RUN**。
- iOS 真机打开/离线阅读：**NOT_RUN**。
- 新 V5 游戏经济真实平衡：**NOT_RUN**；与说明书是否可阅读是两个不同的验收门禁。
