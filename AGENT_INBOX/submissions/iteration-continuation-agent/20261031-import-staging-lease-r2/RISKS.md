# Risks & overlap

- Overlap: Codex #94 uses VeilImportedFileAccess; #92 and #93 stage competing imports. This R2 intentionally does not integrate or silently select them. Governor reconciliation required.
- 24h default TTL can invalidate an unusually long-running/paused restore; do not sweep active leases. Adjust TTL based on device evidence.
- Directory timestamps and wall-clock changes are not cryptographic ownership; missing timestamps fail closed.
- Symlink and File Provider behaviors need iOS verification. Backup staging may include sensitive content; protection settings and lifecycle cleanup remain owned by the importer.
- Standalone Linux XCTest does not prove Apple SDK, iPhone 7, or full-app compatibility.
- Stop on any data loss, consent/touch regression, missing protection or migration failure. No direct main edit, workflow dispatch, version, signing, IPA or self-merge.
