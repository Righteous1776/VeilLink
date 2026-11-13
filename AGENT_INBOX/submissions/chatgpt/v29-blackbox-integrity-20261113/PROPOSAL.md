# [AGENT-DROP] V29 Build66 first confirmed defect repair

## Root cause confirmed in source (not speculative)
`DiagnosticLogStore.exportBundle()` copied physical `runtime*.jsonl` but created manifest and index from `recentEntries` (in-memory, maximum 2000). iPhone 7 ZIP actually retained 72 JSONL records while reporting 2000. Copies also happened after a logging-queue flush but outside the queue, racing background append and log rotation. `flushPendingBufferUnsafe()` removed RAM buffer before calling `append()`; the append caught any write errors and silently discarded the data. This is a plausible data-loss mechanism but is not proven to be the exact cause of the 72-record dump.

## Proposed code repairs
1. `DiagnosticLogStore.exportBundle`: snapshot log files while holding the serial `logQueue` barrier. Derive `manifest.eventCount`, `event-index.eventCount`, category/level counts and time range solely from ZIP-staged JSONL, not in-memory data.
2. Stream individual staged files in 64KiB reads; compute per-file SHA256, byte count, event count, invalid JSONL line count and first/last sequence. Keep `inMemoryEventCount` separate; explicitly report invalid lines.
3. On unsuccessful append, preserve pending entries; roll back partial file writes when possible; retry with five-second backoff rather than creating repeated storage pressure on every UI event. Cap emergency RAM pending buffer to 4MiB, remove complete old lines only and explicitly expose `droppedUnpersistedLineCount`. Export forces one write retry to maximize available evidence. Never block normal app use or expose message plaintext/keys.
4. An `VeilA9HealthMonitor` that has never evaluated a snapshot now says 未评估 (rather than Light: 绿色 / Health 100/100 / Issues: none). Update `lastEvaluatedAt` before publishing a new `decision` so sinks do not misinterpret transient state; initial telemetry emits `a9.not_evaluated`, not false positive health.
5. `DeepTelemetry` distinguishes noisy UIDevice callbacks (`ui.orientation_observed`) from actual changes of interface orientation (`ui.orientation_change`). Only actual changes force expensive hierarchy captures.
6. New `BlackBoxExportIntegrityTests` verifies 120-memory-versus-0-on-disk consistency, SHA256 per copied file, initial A9 status, and orientation event semantics.

## Protected domains NOT modified
No `VeilLink/Transport`, `VeilLink/Security`, Core Wire4, peer identity/keys, DB schema, native AI or game engine edits; no ACK and no canonical assets. This patch does NOT resolve signal11 crashes or physical BLE loss without dSYM/call-stack and synchronized devices. Those remain #191/#185 gates.

## Relation to other lanes
PR #184/#188 stage Veilopoly interaction/layout fixes, do NOT integrate or overwrite them. PR #189 is separate financial autonomy feature. Integration Governor decides merge order after iOS15 build/tests; this candidate has NOT been built or shipped.

## R3: write-first rotation to preserve forensic evidence
Additional source review identified a dangerous retention-order bug even in the first advisory fix: `flushPendingBufferUnsafe` called `rotateIfNeeded(incomingBytes: data.count)` BEFORE `append(data)`. Under disk-full or file-protection failure, the retry could repeatedly shift/delete `runtime.N.jsonl`, permanently discarding old incident records while never persisting a new event. Candidate now calls `append(data)` first, retains pending bytes if that fails, and rotates only after a confirmed write using `rotateIfNeeded(incomingBytes: 0)`. Because rotation occurs after a successful append, a newly appended file may temporarily exceed the per-file threshold until it is moved into the rotation ring; that tradeoff preserves forensic evidence on failed storage operations. This repair does not eliminate I/O errors, partial-write rollback failures or disk exhaustion.
