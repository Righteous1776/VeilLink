# ZeoStudio Memory Layer V1.5

十个编号库 + 记忆指令（最多 50 条活动）+ 睡眠候选审核 + Task/Session 续接摘要。作者：久野零 / ZeoStudio。

先读 `references/01_MEMORY_ARCHITECTURE.md` 和 `references/03_AUTHORITY_AND_SCOPE.md`，再读使用场景对应章节。工具位于 `zeo_memory.py`，由 Python 标准库实现，适合离线桌面；移动端无法持久写入时可使用 `templates/` 的人工移交格式。

**数据库是私有运行时数据，不包含在 Skill 的发布包中。** 此模块不代表任何平台的原生记忆开关已开启，也不具备自行定时运行的能力。
