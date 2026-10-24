# TEST PLAN — conversation-workspace-v1 revision 2

## 自动测试

新增九项 `ConversationWorkspaceTests`：

1. 消息方向、活跃天数和附件总数统计。
2. 中英文行动前缀识别，并排除普通聊天。
3. 问号及自然疑问开头识别。
4. 多链接提取和尾随中英文标点清理。
5. 引用回复仅分析新回复，不重复旧引用。
6. 图片与语音生成可读附件条目。
7. MiniGame 协议包从统计和索引中排除。
8. 条目按时间倒序且具有稳定 ID。
9. 类别与关键词组合过滤。

新增十项 `VeilMessageForgeTests`：

1. 原文样式规范 CRLF 和首尾空白。
2. 紧凑样式折叠行内空白但保留段落。
3. 要点样式拆分中英文句子。
4. 礼貌请求不重复问候或致谢。
5. UTF-8 字节预算对中文正确计数和分段。
6. 分段不拆开 emoji 扩展字形。
7. 私钥与访问令牌被判为严重，处置建议不回显秘密。
8. 密码、邮箱和电话号码分别识别。
9. 空白草稿不能通过单消息检查。
10. 所有内置模板非空且在协议预算内。

## iOS 集成验证

1. 运行 `xcodegen generate`、iOS 15 Simulator build 和全量 XCTest。
2. 在 iPhone 7 上生成 10,000 条混合消息，打开工作台并用 Time Profiler 确认主线程无历史扫描尖峰。
3. 从分页未加载的旧消息生成行动项，点击后确认完整历史已加载并准确跳转。
4. 工作台打开时接收新消息，确认快照刷新且 loading 不会卡死。
5. 同时触发普通聊天 reload 与工作台加载，确认 generation 竞争时按钮恢复可用。
6. 覆盖空会话、全协议包、超长正文、emoji、中文 URL 标点、重复时间戳和损坏链接。
7. VoiceOver 朗读类别、计数、条目日期和跳转按钮；动态字体不截断关键操作。
8. 抓取网络与文件写入，确认工作台没有新增外连或明文持久化。
9. 在消息锻造台逐项验证模板、样式、安全提示、深浅色、动态字体及 VoiceOver。
10. 输入 16 KB 边界、中文、组合 emoji 和超限文本，核对字节数与分段预览。
11. 输入测试令牌/私钥标记，确认“回填”禁用且界面、日志、剪贴板均不出现秘密副本。
12. 从已有草稿打开锻造台并回填，确认只替换编辑框、不自动发送、不改变回复上下文。

## 当前验证

- `git apply --check AGENT_INBOX/submissions/codex/conversation-workspace-v1/PATCH.diff`：PASS。
- `git diff --check -- AGENT_INBOX/submissions/codex/conversation-workspace-v1`：PASS。
- 当前云环境没有 Swift/Xcode，因此未宣称 iOS 编译或 XCTest 已通过。
