# TEST_PLAN — ui-rhythm-token-foundation-001

## 环境
- Linux 沙箱，Swift 6.0.3（ubuntu22.04 工具链），xcrun shim；无 macOS/Xcode
- 验证工作树：a48be364 + local-ci-sim-version-inheritance-fix-001 + legal-consent-first-sign-ime-commit-001（姊妹包）+ 本 patch

## 已执行（真实命令与结果）

| 命令 | 结果 |
|---|---|
| `git apply --check`（本 patch 独立应用于裸 a48be364） | **PASS** |
| `bash scripts/local-ci-sim.sh`（叠加全部三个 patch 的工作树） | **PASS** — exit=0，26 阶段全绿，末行 `LOCAL CI SIMULATION: PASS`，322 个 Swift 文件 parse |
| `python3 scripts/ci-standard-preflight.py` | **PASS** — `VEILLINK_STANDARD_PREFLIGHT_PASS`（322 文件） |
| `git diff --check` | **PASS** — 无空白错误 |
| 替换计数断言（每处编辑脚本化核对期望次数） | **PASS** — 25/25 精确匹配，无多改漏改 |
| sim 断言雷区逐条核对（UI 文件被锁字符串） | **PASS** — 全部被锁字符串保持逐字不变 |
| iOS 真机/模拟器渲染与 XCTest | **NOT RUN** — 本环境无 macOS；属 Governor/CI 门槛 |

## 评审者 3 分钟复核
```bash
git checkout a48be364 && git apply --check PATCH.diff   # 期望: 无输出即通过
git apply PATCH.diff
bash scripts/local-ci-sim.sh                            # 需先应用 local-ci-sim-version-inheritance-fix-001
```
逐处人工核对建议：PATCH.diff 中 22 处应为"同值替换"（字体/间距值前后等价），仅 3 处为数值变化（13→12 ×2、9→8 ×1）。

## 诚实声明
- 不声称任何真机视觉效果；3 处节奏修正的方向性结论（"统一优于 1pt 抖动"）是设计判断，非测量结论。
- 模拟器/真机验证与 XCTest 全量：NOT RUN，移交 macOS CI。
