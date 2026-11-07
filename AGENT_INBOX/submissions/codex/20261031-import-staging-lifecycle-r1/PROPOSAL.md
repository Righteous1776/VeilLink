# Reproduced Build64 bugs

Build64 correctly copies Apple Files provider URLs into app-owned UUID lease directories, but the lifecycle is incomplete:

1. `VeilImportStagingLeasePolicy.sweepExpired(...)` has zero production call sites. A crash or process kill after materialisation leaves the full snapshot forever.
2. Settings and onboarding retain the staged backup when the password sheet is cancelled. Repeated attempts can retain multiple large ZIP files until iOS happens to purge the temporary directory.
3. The settings stress close command clears `restoreURL` without removing its owned snapshot.
4. Chat image sending deletes the staged file but leaves its UUID lease directory behind.

This is application cache leakage. It does not delete or alter the original file in Apple's Files app.

# Proposed repair

1. Run a bounded, age-gated staging sweep once at cold launch on a utility task. The existing policy only accepts direct regular files under a UUID lease, rejects symlinks, retains entries newer than 24 hours, and limits one sweep to 64 removals.
2. Give Settings and Onboarding one `discardRestoreSnapshot()` helper. Call it before replacing an old selection and when the password sheet dismisses, including cancellation.
3. Use the same helper in the settings stress-close route.
4. For imported chat images, first remove an owned lease directory and then retain the existing single-file deletion as a fallback for camera-generated temporary files.
5. Keep restoration synchronous ownership unchanged: `AppModel.restoreBackup` already removes the staged copy in `defer`; dismissal cleanup is intentionally idempotent.

No Files-provider source URL is passed to a delete API.
