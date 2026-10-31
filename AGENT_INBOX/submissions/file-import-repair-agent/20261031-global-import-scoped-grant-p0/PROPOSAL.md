# P0: Make file-provider grant lifetime explicit

- In `materializeInBackground`, call `startAccessingSecurityScopedResource()` in the original picker callback's async task before entering `Task.detached`. Keep scope live until coordinated copy finishes, then release in defer.
- Factor the actual coordinated file copy into `materializeWithHeldScope`, which is used from synchronous materialization with its own scope handling. Prevent non-file URLs from reaching NSFileCoordinator.
- Preserve local and external files' original bytes, cancellable streaming, UUID staging lease and no provider-source deletion; no direct write to file provider.
- In developer training picker, report .failure and empty selection to users instead of silently ignoring.

This does NOT imply that all routes are fixed. Further P0 diagnostic evidence is needed from Files/iCloud/third-party-provider on iOS 15 and iOS 26, including ZIP, HTML, images, backup restore, and training package. Consider building a single `ImportResult` status pipeline after verifying these fixes.

Governor: review against #92/#93/#94/#95 Files changes; patch is only valid for e093e7fb7ab0eb9821a014b753ab2bdc27613ec8. Never auto-merge other overlapping files.
