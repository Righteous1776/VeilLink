# RISKS — legal-consent-first-sign-ime-commit-001

## 风险

1. **按钮 enabled 语义收窄**（本包最大行为变更）：签署按钮现在只随三项确认启用，确认语未填时也可点击（点击后报既有错误文案）。原设计用 disabled 阻止无效签署——安全不变量由 `sign()` 内 `canSign` 评估保证（harness D2 锁定），但交互观感变化需 Governor/Owner 认可。若必须保留 disabled 视觉，需要 UIKit 层暴露合成态（markedTextRange）到视图——更侵入，不推荐。
2. **根因复现基于模型**：harness 复现了"首 tap 被 disabled 吞掉"的机制链条，但 UITextField/SwiftUI Button 的真实事件顺序以 iOS 运行时为准。TC-M1 真机验证是最终裁决；若真机症状不同（如签署后停门页、保存失败），本包应 DROPPED 转向 keychain entitlement / finishActivation 路径。
3. **第三方键盘**：以 `markedTextRange` 为准，系统 API 层面一致，风险低。

## 保护面

未触碰：Protocol 4、VLGM1、SQLite Schema V8、identity/key lifecycle、Transport/Storage、恢复机制、A9/A10、版本/Build、签名/发布 workflow、Governor 授权表。改动 = 1 新增 Core 策略文件（Foundation-only）+ 1 UI 文件 + 1 测试文件。

## 重叠

- 与 #39 同文件正交（#39 修装饰层/滑动识别），diff 基于 #39 之后主线，无冲突。
- 与 K3 包独立；unsigned-ipa.yml reusable workflow 漂移已核实由 K3 包覆盖。

## 回滚

`git revert` 单提交即可；新文件删除无残留；无数据/状态迁移。

## 未解决

- XCTest 未在本环境运行（无 iOS SDK）；合并前需 macOS CI 执行 LegalConsentTests（含新增 2 用例）。
- 真机 IME 端到端（TC-M1）待 Owner 侧验证。

## 权限

无 GitHub 写权限：submission: NOT CREATED。入库需 Governor 按 AGENT_INBOX 流程审查 PATCH.diff。
