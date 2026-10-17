# TEST_PLAN — ui-type-scale-ranks-002

## 已执行（2026-10-17，Linux x86_64 / Swift 6.0.3 ubuntu22.04）

基线合成：main a48be36 + PR #40 patch（git worktree 独立树）。

| 命令 | 结果 |
|---|---|
| `bash scripts/local-ci-sim.sh`（PR #41 修复版，26 阶段） | **PASS**（26/26，322 文件，含 parse/typecheck/harness/合同断言） |
| `python3 scripts/ci-standard-preflight.py` | **PASS**（322 文件，exit=0） |
| `git apply --check PATCH.diff` @ main+#40 独立树 | **PASS** |
| `git diff --check`（空白/冲突标记） | **PASS**（生成时已剔 mode 噪声） |
| 替换计数断言（编辑脚本内置） | **PASS**（13 处，逐模式精确计数，多一处即中止） |

## 视觉审查清单（代码级，供 Governor 对照）

- Settings 10 卡：外观/安全/协议与授权/数据与备份/图片/AI 与灵核/触感反馈/蓝牙与链路 + A9 健康晶格 + 内核运行模式 → 15 semibold rounded
- GameLobby sectionTitle（"本地小游戏"等分区）→ 15 semibold rounded
- LegalConsentGate 2 卡标题：token 化，**零视觉变化**（原值即 15 semibold rounded）

## NOT RUN（诚实标注）

| 项 | 原因 |
|---|---|
| 真机/模拟器渲染 | 无 macOS/iOS 设备；视觉变化以代码审查 + 上述清单为准 |
| XCTest | 无 iOS SDK；改动为 SwiftUI 修饰符字面替换，macOS CI 直接覆盖 |
| local-ci-sim UI 断言影响 | 已核验：本包不触碰任何被断言字符串（设置 A9/内核卡标题不在断言表内），26 阶段全绿为证 |
