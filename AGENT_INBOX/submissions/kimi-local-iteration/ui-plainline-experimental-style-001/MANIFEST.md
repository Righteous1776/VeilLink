# MANIFEST — ui-plainline-experimental-style-001

- agent_id: kimi-local-iteration
- task_id: ui-plainline-experimental-style-001
- status: DROPPED（≠ ACCEPTED ≠ APPLIED ≠ VERIFIED ≠ MERGED）
- date: 2026-10-17
- lane: INBOX_ONLY（五件套投递，无产品树直接修改）

## 基线与依赖（顺序重要）

1. main `a48be36`（fix: restore legal signing interactions, #39）
2. PR #40 `ui-rhythm-token-foundation-001`（未合并，须先合）
3. PR #43 `ui-type-scale-ranks-002`（未合并，须在 #40 之后合）
4. 本补丁（最后应用）

在干净基线（main+#40+#43）上 `git apply --check -R` 反向校验通过，补丁与目标树严格对应。

## 变更文件（6）

| 文件 | 变更 | SHA-256（补丁应用后） |
|---|---|---|
| VeilLink/Core/AppearanceTheme.swift | +71 行：plainline 案例、昼夜双调色板、实验标记 | c111d0b74a66383a932235a8fbc59ad27efe202f908d443ccce5885e4e6960ea |
| VeilLink/Core/AppTheme.swift | 渐变扁平化 + 白描分支（背景/卡片/按压） | 1b0bd4d0e867cacef2a4fb0236e9d77c1f70e8ea580bdfa48b8ad00de2d5e70a |
| VeilLink/UI/AdaptiveRootView.swift | +4/−2：根容器白描首分支 | ab2cfdd7ac6088ea97da252f555bd2d9f45601185f11601cadf687d5a3c9d5e3 |
| VeilLink/UI/PlainlineRootView.swift | 新增 250 行：白描根容器 + 授权闸门 | 949957d8c74556a68bd27974bcd9dc7bca28bcf8e9d9401859b9671aec6dcf3b |
| VeilLink/UI/SettingsView.swift | +51/−4：自由列表过滤 + 白描授权行 | 52185c857202a224727a8d6e7205b683e6a937de47dcfe439f0eff2985ce8f47 |
| scripts/verify-ui-theme-r9.py | 1 行：断言随结构演进（见 RISKS） | 42bbb2c39995f0c825fe2d69c027af1b1914dc7805be74c6be5c516fe3bb2bc3 |

- PATCH.diff：588 行，6 个文件块，+404/−14
- PATCH.diff SHA-256：`d44d6a15fa05ca5a70a09dcd71285ce0a3470cc9f019905309b4854e050b8a6a`

## 保护面声明

未触碰：Protocol 4、VLGM1 v1、SQLite Schema V8、身份与密钥（keychain/PasswordKDF 仅消费既有公开 API `AppLockController.unlock(pin:)`，零修改）、传输与存储、恢复机制、A9/A10 治理、签名/发布/版本门禁。M5 维持 shadow，production_cutover=DENY。
