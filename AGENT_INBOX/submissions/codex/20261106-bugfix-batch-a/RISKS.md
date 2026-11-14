# Risks

## Protected surfaces

- Relay pairing semantics (60-second expiry, X25519, six-digit mutual confirmation), SQLite schema, Wire v4 frame format, M5 shadow, and production-cutover configuration are outside the patch and were checked as untouched.
- `BLETransport` is a high-risk protected behavior surface. Integration must preserve the current GATT watchdog and already-absorbed PR #97 behavior.
- No release, version, workflow, or Issue #6 mutation is included.

## Cross-agent overlap

- PR #133 overlaps `DiagnosticLogStore.swift` for export filename handling. A governor should combine that narrow export behavior with this queue/lock refactor instead of choosing one patch wholesale.
- PR #64 overlaps `RuntimeDiagnosticsBridge.swift` from an older base. It should be reviewed semantically rather than applied after this patch without reconciliation.
- PR #97 overlaps `BLETransport.swift`, but its patch reverse-applies against Build64, indicating its intended GATT change is already incorporated. This proposal preserves those lines.
- No existing PR is closed or modified by this submission.

## Behavioral risks

- `log` becomes asynchronous. A caller that logs and immediately terminates without allowing the queue to drain could lose the newest buffered record; export synchronizes and flushes before building its index.
- Combine/SwiftUI observation is coalesced, so the console may refresh once for several queued records rather than once per call. Lock-backed `recentEntries` snapshots avoid concurrent collection reads.
- The 30-second gate intentionally reduces event granularity. Suppressed counts retain trend magnitude, but exact intermediate values are not persisted.
- Package guidance hard-codes permitted link snapshots at debug level; therefore the prior per-snapshot warning promotion below health 40 is not emitted on every suppressed/allowed snapshot. Oscillation summaries remain info-level. This follows `PATCHES-BatchA.md` but should be checked during telemetry review.
- The application-active flag begins `true` until the existing lifecycle coordinator reports the current state. Lifecycle integration requires an app/device test.

## Reconnect timing changes

- Existing backoff delays and jitter are unchanged.
- Before: GATT notification readiness immediately set `reconnectAttempts[id] = 0`.
- After: GATT notification readiness starts a stable interval; it resets the attempt only after 30 seconds of uninterrupted readiness.
- After: valid peer traffic resets the attempt immediately.
- After: a new reconnect schedule clears the stable marker and, if a prior stable interval has already reached 30 seconds, resets before incrementing the next attempt.
- Net risk: a peer that becomes technically ready but sends no traffic can retain a longer retry tier for up to 30 seconds. This is the intended damping but needs radio/device validation.

## Migration / compatibility risks

- No stored-data or schema migration exists.
- Diagnostic JSON line shape and public event names remain compatible; two aggregate event names (`ble.link_oscillation`, `session.peer_churn`) are added.
- Patch anchors are exact for Build64. If main advances before integration, the governor must rebase/recalculate rather than force-apply stale anchors.

## Performance / battery risks

- A utility serial queue and 30-second telemetry gate should reduce main-thread and disk pressure.
- Lock contention is expected to be short, but only a physical-device trace can confirm it under sustained logging.
- The delayed reconnect-attempt reset can reduce retry churn; it may also extend recovery latency after a transient failure if no valid traffic is observed.

## Security / privacy risks

- No new plaintext field is logged. Existing metadata content is reused.
- Queueing retains log metadata in memory briefly; buffer size and on-disk rotation limits are unchanged.
- No credential, pairing secret, user content, or binary asset is added to the Inbox.

## Validation limitations

- The execution environment is Linux and has no Xcode, UIKit/CoreBluetooth SDK, simulator, or physical iPhone. Parser, strict-concurrency, and compiled harness results are evidence but not a substitute for an iOS build/device gate.
- Repository `local-ci-sim.sh` currently has independent baseline drift: checkpoint/version, BLE typecheck dependency enumeration, privacy-boundary, and A9 guard failures. Untouched-base reproductions were recorded; the relevant files were also typechecked separately with their dependencies.

## Rollback strategy

- Reverse-apply `PATCH.diff` if the device gate regresses stability or latency.
- There is no schema migration, data rewrite, or destructive operation to undo.
- Do not partially roll back only the lifecycle forwarding or retry markers; A2/A3 state transitions should be reverted as coherent units.
