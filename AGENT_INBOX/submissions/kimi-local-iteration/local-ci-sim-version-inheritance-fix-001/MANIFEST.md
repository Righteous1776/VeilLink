# MANIFEST — local-ci-sim-version-inheritance-fix-001

- task_id: local-ci-sim-version-inheritance-fix-001
- agent_id: kimi-local-iteration
- base_main_sha: a48be364f2104ac2532d436ac0f4c1ed45d90e89 (v26.12-b58)
- branch: agent-drop/kimi-local-iteration/local-ci-sim-version-inheritance-fix-001 (local only; no GitHub write permission from this environment)
- status: DROPPED (≠ ACCEPTED ≠ APPLIED ≠ VERIFIED ≠ MERGED)
- lane: INBOX_ONLY（无 LIVE-LANE-GRANT）
- asset_grant: none（不触碰 weights.npz / brain.npz / MaleCNSReference.vfly）

## 变更范围（唯一文件）
- `scripts/local-ci-sim.sh`（+104 / −32，362 行 unified diff）

## 文件清单
- MANIFEST.md — 本文件
- PROPOSAL.md — 问题、证据链、方案
- PATCH.diff — 对 base_main_sha 的真实 git diff（已剔除沙箱挂载导致的 mode 位噪声）
- TEST_PLAN.md — 验证计划与已执行结果
- RISKS.md — 风险与回滚

## 不触碰的保护面
Protocol 4 / VLGM1 v1 / SQLite Schema V8 / 身份与密钥 / 传输与存储 / 恢复机制 / A9/A10 治理 / 发布门禁——本次只改本地 CI 仿真脚本本身，产品树零改动。
