# Reproduced Build64 data-loss bug

Three export paths construct names with `yyyyMMdd-HHmmss`, so two exports in the same second resolve to the same URL:

- `BackupManager.exportBackup` explicitly removes the previous destination before writing the second ZIP.
- `AdaptiveBoardLearningStore.exportPackage` atomically replaces the same training-package path.
- `DiagnosticLogStore.exportBundle` explicitly removes the previous diagnostic ZIP.

Fast repeated taps, automation, or two owner export actions can therefore silently destroy the first export.

# Proposed repair

1. Add one `VeilExportFileName` generator using POSIX millisecond timestamps plus an eight-hex UUID nonce.
2. Route backup, Gomoku/Xiangqi learning and Deep Telemetry exports through it.
3. Remove the pre-delete calls; a fresh unique destination must not need destructive preparation.
4. Preserve all current prefixes and suffixes so the storage cleanup allow-list and user recognition remain compatible.
5. Add deterministic tests proving same-moment names differ and training-package cleanup contracts remain intact.

The contents and cryptographic protection of each export are unchanged.
