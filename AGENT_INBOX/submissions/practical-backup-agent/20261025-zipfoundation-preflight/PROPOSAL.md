# Practical R3: Preflight VeilLink v1/v2 ZIP archives BEFORE restore

VeilLink Build61 BackupManager already limits ZIP bytes (200 MiB), extracted total size (350 MiB), and file count (10,000), rejecting unsafe paths and symlinks. Missing capabilities: case/Unicode alias collisions, duplicate ZIP entries, compression ratio anomalies, early required file preview, a user-operated read-only report, and optional full CRC checking without extraction.

This package adds:
1. **Pure Foundation metadata policy:** allow only `manifest.json`, `database.enc`, `storage-key.enc`, `identity.enc`, `attachments/`, and attachment UUID `.bin` names. Check duplicate and filesystem alias paths, symlinks, traversal, size/entry-count ceilings, decompression ratios, required files and declared compressed sizes.
2. **ZIPFoundation inspector:** read-only Archive `.read`, bounded metadata scan and manifest extraction with CRC; validates unencrypted v1/v2 header without exposing `identityID`, `salt` or ciphertext. Optional streaming full-archive CRC with 32 KiB chunks, no writing to disk. Does NOT verify password or restore database.
3. **SwiftUI document picker:** user selects ZIP and chooses metadata-only or full CRC; displays counts, size, version, time and safe messages; clears ephemeral UI state on dismiss.
4. **Proposed restore guard:** `BackupManager.restoreBackup` calls read-only preflight after legacy `validateArchiveBeforeExtraction` and before `unzipItem`. Governor may defer this higher-risk touch until exact real v1/v2 fixtures are tested. No backups altered and rollback procedure unchanged.

Compatibility and ownership: uses **existing** ZIPFoundation, no new SPM packages. No schema, protocol, identity, Keychain, payload or backup format changes; no automatic rekey, reset, delete, or network.
