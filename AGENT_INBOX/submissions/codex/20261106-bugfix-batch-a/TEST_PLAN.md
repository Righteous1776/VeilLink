# Test Plan

Every line uses the required `<command> → <result> → PASS/FAIL/PENDING` convention. Linux/container checks are not physical-device or Xcode claims.

## Static checks

- `sha256sum 1-veillink-bugfix-package-20261106.zip` → `3fc839004f45601600cf2caefbf13ac9a25227dbc5e44c0e81200974e5843b15` → **PASS**
- `GitHub API default-branch commit/tree lookup` → commit `ccafebab147e069fbabfff579dbf323b0d54f191`, tree `6b2493d2c4297da0ad539fff68ce3ada59cebe68` → **PASS**
- `git diff --check` → no whitespace errors → **PASS**
- `git diff ... | git apply --check --whitespace=error-all -` against clean base → applies cleanly → **PASS**
- `git diff --diff-filter=D --name-only` → no deleted paths → **PASS**
- `tree-sitter parse` for all repository Swift files → `SWIFT_PARSE_PASS files=447` → **PASS**
- `swiftc -swift-version 5 -strict-concurrency=complete -typecheck ... DiagnosticLogStore.swift` with Linux API stubs → zero errors → **PASS**
- `swiftc -swift-version 5 -strict-concurrency=complete -typecheck ... BLETransport.swift BLEGattHandshakeWatchdog.swift` with Linux CoreBluetooth/Combine/diagnostic stubs → zero errors; stub/existing annotation warnings only → **PASS**

## Unit tests

- `DiagnosticLogStore` compiled runtime harness with 100 concurrent `log` calls → 100 unique monotonically sorted sequence numbers, 100 JSONL rows, and successful clear → **PASS**
- `BLELinkReliabilityPolicy` compiled executable harness → reset false before 30 seconds and true at/after 30 seconds; output `BLE_RECONNECT_DAMPING_POLICY_PASS` → **PASS**
- `xcodebuild test` for `DiagnosticLogStoreTests` and `BLELinkReliabilityPolicyTests` → macOS/Xcode unavailable in this environment → **PENDING**

## Integration tests

- `scripts/local-ci-sim.sh` → stops at the existing checkpoint assertion (`docs/CHECKPOINT_CURRENT.md` does not name marketing version 27.2); same failure reproduced on untouched base → **FAIL (baseline blocker, not introduced by patch)**
- `scripts/local-ci-sim.sh` remaining runnable sections, executed after recording the baseline blocker → Swift parse, Linux-compatible core typecheck/runtime, VeilFly C/kernel/payload, VFLY graph concurrency, source lock, performance override, Agent Foundation/runtime, haptic stub, shell syntax, and iOS 15 guard pass; later pre-existing Agent privacy/A9 guards fail and reproduce on untouched base → **FAIL (baseline blockers, not introduced by patch)**
- `xcodebuild build` for the iOS application → macOS/Xcode unavailable → **PENDING**

## Negative / failure cases

- App enters background while snapshots/peers publish → both sinks must return without persistence → **PENDING physical-device/instrumented app test**
- Link oscillates repeatedly inside 30 seconds → intermediate samples are counted and next allowed event carries `suppressed_count` plus `oscillation=true` → **PENDING Xcode unit/integration test**
- GATT becomes ready but carries no peer traffic → reconnect attempt must remain until 30 seconds of stability → policy boundary harness passes; full BLE integration → **PENDING physical-device test**
- Valid peer traffic arrives during damping → reconnect attempt resets immediately → source path/typecheck pass; full BLE integration → **PENDING physical-device test**

## Regression invariants

- `rg/diff review` of changed paths → Relay pairing, X25519, six-digit confirmation, SQLite schema, Wire v4, M5 shadow, and `production_cutover` configuration are untouched → **PASS**
- `git diff` of reconnect policy → existing retry-delay constants and jitter formula are unchanged → **PASS**
- `git diff` of Inbox branch → only `AGENT_INBOX/submissions/codex/20261106-bugfix-batch-a/` is committed; product changes remain in `PATCH.diff` → **PASS**

## Device / OS coverage

- iPhone 7, supported iOS, two-hour foreground/background/lock-screen run → unavailable to Codex environment → **PENDING owner physical-device gate**
- Compare stalls, mean stall duration, `link_snapshot` count, and startup signpost against supplied baseline → no post-change device capture yet → **PENDING owner telemetry capture**
- Repeated Bluetooth cutoff/re-enable and peer traffic recovery → no device radio available → **PENDING owner physical-device gate**

The Batch A gate is therefore not declared passed. Batch B and Batch E must remain unstarted until the owner supplies/evaluates the physical-device results.
