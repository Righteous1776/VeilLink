# VeilLink Diagnostic Flight Recorder R2 — Global Coverage / Five-Night Evidence

## 1. Why V1 is insufficient

V29.1 Build 67 contains a working DiagnosticLogStore, DeepTelemetry and MetricKit, but the prior candidate's 192 MiB budget has no demonstrated five-evening coverage. New VeilLink modules are not automatically instrumented merely because UI and global touch probes exist. Consequently, **coverage completeness** and **retention completeness** must be audited independently. Never claim arbitrary iOS process or private system-log access.

Assumption used only for sizing illustration: five nights × three hours = 15 active hours. 512 MiB / 15 h ≈ 9.7 KiB/sec average. It is a target budget, not measured event throughput and NOT a guarantee of five nights.

## 2. Actual staged code proposal (PATCH.diff)

**512 MiB configured budget:** 24 × 16 MiB JSONL segments (384 MiB) and 128 MiB auxiliary; auxiliary file cap 32 MiB / 96 files; in-memory last 6,000; pre-consent fixed schema 512. Pending 4 MiB RAM buffer and post-successful-append rotation are deliberately preserved. No new permission or background mode is declared.

**Retention evidence:** Count and persist the number of overwritten oldest segments in `retention-evictions.json`; include `rotationEvictionCount` and `retainedTimeSpanHours` (actual earliest/latest captured timestamps from export) in the ZIP manifest. Provide owner-visible disk utilization and eviction count. If either the span is short or evictions occurred, do not call the archive a complete multi-night record.

**Content-free UI chronology:** ChatView's actual visible row order is captured via ephemeral per-session tokens, ordinal, direction, delivery state, timestamp, attachment presence and non-plaintext flag. New observations are deduplicated; no message body, search phrase or persistent message IDs are exported by this channel.

**Feature evolution:** `VeilFeatureLibraryView` automatically emits an inventory for the existing `VeilFeatureRegistry` on open and reports a typed `feature.open` checkpoint. The export index records `registeredFeaturePacks`, `moduleCheckpointCounts`, and `unobservedRegisteredPacks`. A new feature registered here will appear in this inventory without editing the recorder. A pack missing an event is described as *not observed during this capture*, not necessarily uninstrumented or broken.

**Integration API:** `RuntimeDiagnosticsBridge.recordModuleCheckpoint(module:phase:counters:flags:level:)` accepts only identifier-shaped module/phase strings and integer/Boolean telemetry. Future BLE/LAN/Relay/Community/Game/Agent/Storage/AI lanes should emit checkpoints on lifecycle, enqueue, retry, timeout, failure and recovery. This is opt-in per module; no reflective or private UI scraping.

**Owner controls:** Add explicit “开启全部本机诊断采集” in the existing owner-protected console; it enables four already supported in-app DeepTelemetry categories (raw touch, input lifecycle without text, post-interaction UI hierarchy metadata, performance). It does not acquire OS or other-app privileges; switches stay on until the owner disables them.

## 3. Permission model, bounded by reality

| Scope | Implementation | Permission |
|---|---|---|
| App lifecycle, own UI and bubbles | Current app-owned events and new typed checkpoints | Within app, with owner settings where sensitive |
| BLE/LAN/Relay internals | Add module-specific state counters and correlation IDs | Only own transport state, no captured user payload |
| Own SQLite migrations/error codes | Add typed step/failure events; no table dumps | Sandbox data only |
| MetricKit crash/hang/energy | Existing MetricKit integration, OS delivery scheduling | Official OS API, no guaranteed immediate full history |
| Keychain/identity | Log access outcome/error *codes*, never secret values | Existing scoped app authorization |
| Other applications / system-private logs / sandbox escape | Not included | Not granted; no bypasses or privilege escalation |

## 4. Follow-on integration milestone: not falsely claimed as implemented

A five-night guarantee **cannot** be promised from a 512 MiB circular JSONL store. Before release, implement and validate: (A) daily partitions or archived segments with age-aware eviction; (B) stream-compressed cold segments and integrity checks; (C) incident-priority reserve to prevent routine high-volume UI events erasing crash causality; (D) bounded volume telemetry per subsystem with visible suppression/drop counters; (E) segment-by-day export instead of one enormous ZIP; (F) time-coverage and free-space forecasting from measured foreground write rate; (G) module-specific coverage obligations plus CI check for every newly added feature. Consider owner-configurable 1 GiB only after actual storage/power measurements.

No benchmark has established the 512 MiB budget will last five nights, so the product must label retention completeness honestly and allow export after sessions.

## 5. Compatibility and release governance

Zero database/wire/crypto migrations. Existing diagnostic JSONL v2 keeps its schema. Only new optional export metadata and additive feature checkpoints are proposed. Main remains unchanged; PR #222 is INBOX_ONLY, Draft; no release/IPA has been triggered.
