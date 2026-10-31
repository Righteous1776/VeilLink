# R3 review risks

- **Protected restore path.** This adds a fail-closed guard at `BackupManager.restoreBackup` proposal level, not production yet. An overly strict allowlist can refuse valid old backups. Governor should initially approve read-only Tools UI and gate restoration only after fixture compatibility proof.
- **Global UI conflict.** `ToolCenterView.swift` has competing cards from other agents, plus `Storage control center` PR #50; manual arbitration required.
- **ZIP metadata is untrusted.** ZIPFoundation 0.9.19 Archive .read exposes declared compressed/uncompressed entry sizes and CRC, not decryption status. The read-only path enforces size/count/alias/path limits before any extraction. The optional deep CRC checks bytes but cannot validate encrypted payload correctness, backup password, SQLite or identity keys.
- **Zip bombs / CPU.** Per-entry ratios and expanded aggregate cap are heuristics; deeply malformed central directories and expensive DEFLATE data can still cost CPU. Full CRC is explicit opt-in, performed off main with 32 KiB chunks, preflight screens declared sizes first.
- **File provider / concurrent modification.** Files/iCloud provider might modify bytes after preflight and before actual restore. Existing BackupManager still performs its own path and post-extraction checks; preflight is defense in depth, not a TOCTOU guarantee.
- **Memory / input bounds.** Entry metadata array capped at 10001 entries, file names 1024 UTF-8 bytes, manifest <=128 KiB, archives <=200 MiB. Filenames/identity are not copied into UI report; only problem categories and safe metadata are shown.
- **Device support.** iOS15 SwiftUI and ZIPFoundation API shape have not had a full Apple SDK compile/test. `@MainActor` backup restore call might gain a short synchronous scan; measure actual latency before gate.
- **No data loss tolerance.** Do not delete backups, wipe SQLite/Keychain, force recreate identity, bypass user confirmation or automatically import data.
