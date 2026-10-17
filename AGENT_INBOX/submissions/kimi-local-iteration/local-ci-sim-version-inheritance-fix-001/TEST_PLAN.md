# TEST_PLAN — local-ci-sim-version-inheritance-fix-001

## 环境
- Linux 沙箱（无 macOS / xcodebuild / xcodegen）
- Swift 6.0.3 Linux 工具链（/opt/swift/usr/bin），xcrun shim 透传
- 基线：main a48be364f2104ac2532d436ac0f4c1ed45d90e89（v26.12-b58）

## 已执行（真实命令与结果）

| 命令 | 结果 |
|---|---|
| `bash scripts/local-ci-sim.sh`（修复前，基线 a48be364） | FAIL — 首个 Python 断言即失败（Info.plist 版本继承） |
| `bash scripts/local-ci-sim.sh`（修复后，本 patch） | **PASS** — exit=0，26 个阶段全绿，末行 `LOCAL CI SIMULATION: PASS` |
| `python3 scripts/ci-standard-preflight.py`（修复后） | **PASS** — Swift parse 321 files，`VEILLINK_STANDARD_PREFLIGHT_PASS` |
| `git diff --check` | **PASS** — 无空白错误 |
| `git diff --stat` | 仅 `scripts/local-ci-sim.sh`，+104/−32 |
| 慢速自对弈确定性 smoke（`VEILLINK_RUN_SLOW_TRAINING_SMOKE=1`） | NOT RUN — 脚本自身设计为默认跳过（编译耗时分钟级），CI 可选择开启 |
| xcodebuild 真机构成 / 模拟器运行 | NOT RUN — 本环境无 macOS；脚本内已显式声明该门槛仍属 macOS/GitHub CI |

## 复核方式（评审者 3 分钟可复现）
```bash
git checkout a48be364 && git apply PATCH.diff   # 或 checkout 本分支
export PATH=<swift-linux-toolchain>:$PATH
bash scripts/local-ci-sim.sh        # 期望: LOCAL CI SIMULATION: PASS
python3 scripts/ci-standard-preflight.py  # 期望: VEILLINK_STANDARD_PREFLIGHT_PASS
```

## 诚实声明
- 本 patch 只验证脚本在 Linux 本地恢复全绿；不声称任何 iOS 真机/模拟器结果。
- GitHub 远端推送、Draft PR、Inbox Gate 运行：NOT RUN（本环境无仓库写权限）。
