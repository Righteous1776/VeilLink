# Required tests and gates — NOT_RUN here

## Static checks completed
- Read V29 main commit eb487a1901c0ffddfb38b80b9fb56f6d7d749ba0; localized diagnostic defects.
- Validate unified `PATCH.diff` round trip to all candidate Swift files. 19 hunks in five paths. No production branch modifications.

## Apple build/verification (must execute before merge)
1. Apply candidate patch on fresh integration branch from V29 main. Build with Xcode targeting iOS 15 and run `BlackBoxExportIntegrityTests` + all existing `DiagnosticLogStoreTests`, `A9HealthLatticeTests`, BLE and host XCTest.
2. Run instrumentation test: log 120 entries, flush, truncate a copied log on test device. Confirm exported actual eventCount=0 and inMemoryEventCount=120; no misleading 120 in event-index. Run rotated logs test with 8 files, valid/corrupt records and first/last sequence. SHA256 of each archived file must match extracted bytes.
3. Force disk write failure (permissions, locked protected storage, low storage). Confirm bounded RAM <=4MiB, no unbounded retries, loss counter appears and any available complete records survive a later successful retry.
4. Export on iPhone7 immediately after first signature, active loop/high event volume and background/foreground transitions; monitor memory/CPU and ZIP consistency. Never destructively clear an owner's real logs.
5. Without a9Health.evaluate, report not-evaluated and `a9.not_evaluated`. After one evaluate, use actual decision numbers. Test no false 100/100 nor transitively assumed connection.
6. Repeated UIDevice orientation callbacks at constant portrait must be `ui.orientation_observed`. Rotating to actual landscape must emit `ui.orientation_change` once; see iOS15 + iOS26.
7. Re-run same export logic on iPhone SE2, ensure event count=560-equivalent or new valid counts, no index/cache discrepancy.
8. Symbolicate Build66 signal11 with exact Mach-O/dSYM; unrelated crashes are NOT resolved by this diagnostic patch.
9. Independently reproduce BLE and Veilopoly invite secure/control gate; Issue #185 remains open until real two-iPhone P0 test passes.

## Success bar
No iOS compatibility regression; crash/hang profile does not worsen; manifest/index equal actual archived valid lines, and per-file digest correct. All tests and real devices documented with build SHA. No IPA dispatch at this Inbox stage.

## Write-first retention regression
- `testFailedWriteNeverRotatesAwayPreviouslyRetainedLogs`: create a pre-existing oldest `runtime.7.jsonl` sentinel, block appending via an active path that is a directory, queue >2MB of event lines, then force export's serial flush; despite expected ZIP export failure, old rotated file bytes must remain identical.
- On iOS15 force a repeated write failure using protected file access, exhausted test volume or controlled FileManager error injection. Assert rotation filenames and checksums are unchanged until an append succeeds; when the storage resumes, pending buffer eventually flushes and retained older logs rotate according to quota.
- Measure RAM and file-size overshoot for up to a 4MB pending buffer; verify ZIP snapshot/hash/index still accounts for every *included* JSONL and does not count inaccessible records as exported.
