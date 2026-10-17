# PROPOSAL — legal-consent-first-sign-ime-commit-001

## 问题

法律同意门页"首次无法签约"：首次点击"签署并进入 VeilLink"无响应，输入法提交后再次操作才成功。main 上的 #39 修复了装饰层/滑动识别拦截，症状仍在。

## 根因（双重缺陷，已由行为级 harness 复现确认）

`LegalConsentGateView` 的签署入口存在两个叠加缺陷：

1. **状态污染**：`Coordinator.textChanged` 无条件 `text.wrappedValue = field.text`。拼音输入法候选窗未提交时 `field.text` 是合成中间串（`markedTextRange != nil`），进入 `acknowledgment` 后 `canSign=false`。
2. **动作不可达**：签署按钮 `enabled: canSign` 被 `.disabled(true)` 后，SwiftUI 在 action 之前吞掉 tap——`sign()` 根本进不去，用户看到的就是"首次点击毫无反应"。即使提交合成后状态恢复，损失已经发生。

排除项（均有代码证据）：`KeychainStore.set` 首次写入正确回落 `SecItemAdd`；`accept()` 写后同值 validate 自洽；`VeilStableScrollView`/`VeilReleasePrimaryButton`/激活页接线无手势拦截；遥测不影响交互。

复现证据：`FILES/harness-run.log` 场景 A——pre-fix wiring 下首 tap 返回 `__tap_swallowed__`，仅合成提交后才可签署；场景 B——post-fix wiring 同事件流首 tap 直接签署成功。

## 设计

**新增 `VeilLink/Core/LegalConsentInputPolicy.swift`（Foundation-only）**，迁入 `VeilLegalConsentRequirements.canSign` 与 `VeilLegalAcknowledgmentInput.publishableText`，使签署门决策逻辑脱离 UIKit 可独立编译、可执行测试。

`LegalConsentGateView.swift` 三处修复：

1. `textChanged` 经 `publishableText` 过滤：合成中（markedText）不发布，状态保持"最后已提交文本"。
2. **按钮 enabled 改为 `confirmationsReady`**（三项稳定确认）：签署动作不再被输入法瞬态锁死，始终可达。
3. `sign()` 内先 `resignFirstResponder` 提交悬置合成（UIKit 同步触发最终 `editingChanged` 回写提交文本），再评估 `canSign`：合法即签署，不合法显示既有错误文案。`canSign` 仍用于输入框视觉强调（金框/描边），语义不变。

不变量：无完整三项确认 + 准确确认语，绝无签署可能（harness 场景 D 锁定）；确认语文本、keychain 合同、`accept()` 持久化逻辑、视图结构、accessibility/遥测标识全部不变。

## 兼容性

- 英文/粘贴输入路径不变；候选窗开着直接点签署一次成功（原需先提交）。
- 按钮在确认语未填时也可点（视觉态由 `canSign` 强调区分），点击后给出明确错误文案——优于原"点了没反应"。
- XCTest 现有用例全部保留；新增 2 个用例覆盖 `publishableText` 合成过滤。

## 实施说明

PATCH.diff 共 3 文件、+92/-20 行（163 行含上下文），基于 `a48be36`，`git apply --check` PASS。保护面（Protocol 4 / SQLite V8 / 密钥 / A9-A10 / workflow / 版本 Build 58）：均无触碰。
