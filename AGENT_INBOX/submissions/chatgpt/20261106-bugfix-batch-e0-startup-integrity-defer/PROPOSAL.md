# E0 — 将全库 SQLite 完整性检查移出首屏主线程

## Source facts
- `AppBootstrap.initializeModel()` constructs `AppModel` synchronously in the SwiftUI startup path.
- `AppModel.init` calls `refreshA9Health()`.
- `refreshA9Health()` calls `runAutomatedIntegrityCheckIfNeeded()` on first invocation.
- The latter invokes `DatabaseStore.integrityCheck()`, which performs FULL `PRAGMA integrity_check;`, potentially scanning a growing SQLite database before first frame.
- `DatabaseStore` serializes access via its own `studio.zeo.veillink.sqlite` queue.

## Proposed candidate
- Preserve fail-closed DB key verification, migrations, startup metadata cleanup and full integrity semantics.
- Gate routine A9 refresh until startup check is run; retain database health `.unchecked` (not fabricated `.ok`) during this period.
- Schedule one first-foreground check after 750ms, execute full PRAGMA on utility DispatchQueue and send the result to MainActor. A later manual database check takes precedence.
- If app enters background before deferred check starts, retry on next foreground.
- Preserve the existing 6h check cooldown and failure log events after completion.

## Scope
No direct source mutation here; the patch is advisory and needs strict concurrency, read/write queue contention and actual launch timing validation. This is a reduction of synchronous cold-start work, not a guarantee of lower overall CPU or faster launch on all devices.
