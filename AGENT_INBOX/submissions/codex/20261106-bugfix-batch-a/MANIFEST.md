# Submission Manifest

- agent_id: codex
- task_id: 20261106-bugfix-batch-a
- status: DROPPED
- base_main_sha: ccafebab147e069fbabfff579dbf323b0d54f191
- created_at: 2026-11-06T10:19:32Z
- scope: Batch A only — diagnostic logging off-main serialization, link/peer telemetry damping, and BLE reconnect damping.
- proposed_files:
  - VeilLink/Diagnostics/DiagnosticLogStore.swift
  - VeilLink/Diagnostics/RuntimeDiagnosticsBridge.swift
  - VeilLink/App/VeilAppLifecycleCoordinator.swift
  - VeilLink/Transport/BLELinkReliabilityPolicy.swift
  - VeilLink/Transport/BLETransport.swift
  - VeilLinkTests/DiagnosticLogStoreTests.swift
  - VeilLinkTests/BLELinkReliabilityPolicyTests.swift
- protected_surfaces: BLE reconnect scheduling behavior and diagnostic persistence internals; no pairing, database, wire-format, release, or production-cutover contract is changed.
- dependencies: none
- known_overlaps:
  - PR #133 proposes DiagnosticLogStore export-filename collision handling; this patch changes the same file for queueing/locking and must be integrated deliberately.
  - PR #64 proposes older RuntimeDiagnosticsBridge stability work; this patch changes the same file against the newer Build64 base.
  - PR #97 names BLETransport; its proposed GATT changes are already present in Build64 (its patch reverse-applies) and are preserved here.
- source_prompt_summary: Owner directive dated 2026-11-06 plus veillink-bugfix-package-20261106.zip; ORIGINAL_REPORTS.md has highest semantic priority, PATCHES-BatchA.md supplies implementation guidance, and Build64 is the verified source baseline.
- asset_grant: not applicable; no ASSETS/ or binary resources

## Baseline and provenance

- Package SHA-256: `3fc839004f45601600cf2caefbf13ac9a25227dbc5e44c0e81200974e5843b15` (verified).
- GitHub default-branch commit at start: `ccafebab147e069fbabfff579dbf323b0d54f191` (verified through the API).
- Git tree: `6b2493d2c4297da0ad539fff68ce3ada59cebe68` (matches the package directive).
- The supplied ZIP contains eleven Markdown specification/evidence files and no Git repository or source mirror; implementation was therefore produced against the verified GitHub Build64 commit.
- The instruction says 16 bridge wrappers; the verified Build64 source contains 19 `Task { @MainActor ... store.log(...) }` wrappers. All 19 real occurrences are handled individually; unrelated tasks remain.

## Batch A redline self-check

- [x] Relay pairing semantics are unchanged: the 60-second expiry, X25519 exchange, and six-digit mutual confirmation are untouched.
- [x] SQLite schema and all database migrations are unchanged.
- [x] Wire v4 frame format is unchanged.
- [x] M5 shadow and `production_cutover` configuration/semantics are unchanged.
- [x] Marketing/build versions, workflows, releases, and workflow dispatch are unchanged.
- [x] No file is deleted, reverted, or version-downgraded.
- [x] Product-tree changes are supplied only as `PATCH.diff`; this Inbox branch itself changes only this submission directory.
- [x] Container/Linux and parser results are not represented as simulator, Xcode, or physical-device results.

## Telemetry comparison

| Metric | DeepTelemetry 2026-11-06 baseline | After Batch A |
|---|---:|---:|
| Main-thread stalls | 1,081 | PENDING physical-device gate |
| Mean stall duration | 917 ms | PENDING physical-device gate |
| `link_snapshot` events | 3,095 | PENDING physical-device gate |
| Startup signpost | `< 1 s` in supplied evidence | PENDING Batch B/device measurement |

No post-change physical-device numbers are available in this execution environment; no qualitative speed claim is made.

## Owner decisions carried forward verbatim

1. **⑩ 自博弈导出**：owner 原话“五子棋自博弈详细具体功能不能导出”。镜像实锤：`GameLobbyView.swift:644` 已有“导出训练包”按钮 → `exportBoardLearning()` → ShareSheet。**澄清**：是指该按钮失效（点不动/内容空），还是要自博弈对局记录独立于训练包导出？两分支代码 `PATCHES-BatchD.md D3` 已备好，澄清前不动工。
2. **⑥ 灵核建议**：owner 原话“灵核不用给到游戏建议，无法执行建议”。按上下文解读为“建议存在但无法执行”；若原意是“不要给建议”，D2 需求整体反转（改隐藏建议而非接通执行）。澄清前 D2 不动工。

These decisions do not block Batch A. No Batch D source is included in this submission.
