# Risks and stop conditions

## P0 / protected surfaces

- A9/A10 labels and status selection touch governance presentation. The patch does not grant mutation authority or alter the runtime selector contract, but requires protected review.
- Backup restore remains destructive to local app state after password verification. The new staging layer only fixes file access; existing confirmation and backup validation must remain intact.
- Apple Files behavior varies by provider. The staging copy is moved off the main actor, uses 1 MiB cancellation checkpoints, and is deleted on every known terminal path; physical tests must still cover iCloud Drive and at least one File Provider extension, including cancellation during a 200 MiB copy.
- `UIFileSharingEnabled` intentionally exposes the app Documents directory in Apple Files. Current Documents output is encrypted backup ZIP data, while protected databases/attachments/identity state remain in private storage. Integration must audit every future Documents writer and must not place plaintext secrets or internal database files there.

## Learning storage

- Removing artificial caps means training data can grow. Writes remain atomic and naturally fail if iOS reports no space; the UI reports write failure. Governor may add a visible disk-pressure pause, but must not silently prune or merge the two games.
- The current uncapped store is still a whole-file JSON database: each save encodes and atomically rewrites the complete history, launch decodes it, and snapshots materialize remembered positions. Metadata and opening-analysis hot paths are bounded here, but truly large histories still require iPhone 7 profiling and a separately reviewed transactional/append-only migration; this patch must not claim unlimited performance merely because it removes artificial caps.
- Invalid V1/V2 bytes are retained and autosave is fenced off. Users must explicitly clear or import a checksum-valid package to recover; the UI currently exposes write unavailability but does not provide a forensic repair browser.
- V1 migration can recover exact positions by prefix. A V2 target is written only after an encode/decode verification in a sibling staging file, while the shared V1 file is left byte-for-byte intact. Old aggregate `completedGames` cannot be perfectly split if its old 40-record history had already discarded earlier per-game records; the migration intentionally counts only surviving game-typed records rather than inventing attribution.
- This is lightweight repertoire/sequence learning, not unrestricted neural training. It becomes observably adaptive but does not guarantee victory.
- “宗师” is a device-aware local search budget, not a claim of a cloud grandmaster engine. It can take longer on old devices; the candidate caps the legacy iPhone 7 budget and requires thermal, foreground/background and cancellation testing before promotion.
- Third-party engine source has not been silently imported. MIT candidates have been identified, but file-level provenance, attribution and iOS integration still need the intake gate recorded in `THIRD_PARTY_CHESS_ENGINE_AUDIT.md`.
- The developer learning room changes Owner Mode capability policy and Keychain-backed authorization. Its eight-digit PIN is deliberately only a surface factor; secure storage, device secret, session expiry, God Mode prerequisite and app-lock prerequisite need independent review. There is no hard-coded recovery password: loss of the owner-selected PIN requires an explicit future reset/re-enrollment design, not a hidden bypass.
- A recorded formation is deliberately a high-priority local tactical preference, not an unconditional move. Integration must test that its proposed response remains legal after a matching prefix and that ordinary tactical win/block rules still prevail. Recording starts from a fresh board and uses a separate buffer so demonstrations cannot contaminate the public learning store.
- Formation lessons are integrity-protected by a device-local Keychain MAC key. Keychain reset/reinstall makes old local lesson files unverifiable by design; the candidate must not silently accept them. Any future export/import of these private lessons needs its own authenticated format and owner review.

## 三国兵器

- V2 WEGO currently resolves movement/contact, not a complete casualty/end-state campaign. The candidate restores the large battlefield and playable turn loop; deeper combat remains a later feature.
- Old small-board code remains compiled for encrypted-history/protocol compatibility, but no current visible lobby or V2 negotiation UI renders it.

## Galgame blocker

The complete owner-supplied Monogatari R5 artifact is not present in main, GitHub Inbox or current attachments. Exact recovery is blocked; see `GALGAME_RECOVERY.md`. Do not claim the native Story Lab is the requested full Galgame.

## Stop conditions

- Patch apply failure, XcodeGen failure, Swift compile failure, any P0 touch/import/consent regression, checksum mismatch, database migration failure, or lost A10 telemetry => HOLD.
- No main merge, version bump, signing, IPA build or release from this submission.
