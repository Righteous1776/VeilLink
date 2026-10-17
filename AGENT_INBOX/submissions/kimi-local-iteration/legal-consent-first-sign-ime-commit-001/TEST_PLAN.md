# TEST_PLAN — legal-consent-first-sign-ime-commit-001

## 用例

| 用例 | 类型 | 预期 | 实测 |
|---|---|---|---|
| A1-A3 修复前复现 | 行为 harness（Linux 可执行） | 合成态污染 canSign → 首 tap 被吞；提交合成后才可签署 | PASS（harness-run.log） |
| B1-B2 修复后签署 | 行为 harness | 合成中状态不污染；候选窗开着首 tap 一次签署成功 | PASS |
| C1-C2 普通输入回归 | 行为 harness | 已提交文本正常签署 | PASS |
| D1-D2 不变量 | 行为 harness | 缺确认/错误确认语仍被拒并给出错误文案 | PASS |
| E1-E3 publishableText 矩阵 | 单元（harness + XCTest 双实现） | marked→nil；committed→原文；nil→"" | PASS |
| TC-XT1 门页既有逻辑 | XCTest（macOS CI） | LegalConsentTests 全部保留并通过 | NOT RUN（本环境无 iOS SDK） |
| TC-M1 真机 IME 端到端 | 手动（iOS 设备 + 拼音键盘） | 候选窗未提交时点签署一次成功 | NOT RUN（无设备） |

## 环境与命令（2026-10-17 实测）

环境：Linux x86_64 / Swift 6.0.3 (ubuntu22.04) / 仓库 `/tmp/veillink-main` @ `candidate/legal-consent-first-sign-ime-commit-001`。

| 命令 | 结果 |
|---|---|
| `swiftc -O LegalConsentInputPolicy.swift Shim.swift main.swift -o harness && ./harness` | PASS，12/12（run_rc=0，日志 FILES/harness-run.log） |
| 干净 clone 应用 PATCH 后重跑 harness | PASS（端到端复核） |
| `swiftc -frontend -parse`（3 个改动文件） | PASS |
| `python3 scripts/ci-standard-preflight.py` | PASS（322 文件，exit=0） |
| `python3 scripts/verify-recovery-lineage.py` | PASS（237 源文件 / 85 测试文件） |
| `git apply --check PATCH.diff` @ a48be36 | PASS |
| `bash scripts/local-ci-sim.sh` | FAIL — stdin 第 12 行版本继承断言（`$(MARKETING_VERSION)`），pre-existing，属 K3 包范围 |
| LegalConsentTests（XCTest） | NOT RUN — 无 iOS SDK；新增用例为纯逻辑，macOS CI 可直接执行 |

## harness 忠实性说明

harness 驱动的是产品代码中的真实函数（`canSign` / `publishableText`）。`VeilLegalConsentController` 因依赖 Combine/CryptoKit 无法上 Linux，`requiredAcknowledgment` 由同值 shim 提供（FILES/Shim.swift，值镜像自 Controller.swift 第 19 行）；Controller 真实集成由 macOS XCTest 覆盖。模拟的事件流忠实于 UIKit：合成中 `hasMarkedText=true` 且 `text` 为中间串；提交触发最终 `editingChanged`。

## 回归审查

版本/Build（26.12/58）、Protocol 4、SQLite V8、身份密钥合同、A9/A10、workflow、资源 hash：均未触碰；`canSign` 语义不变（仍用于视觉强调与签署评估）。
