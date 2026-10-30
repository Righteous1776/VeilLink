# Risks and stop conditions

## P0 / protected surfaces

- A9/A10 labels and status selection touch governance presentation. The patch does not grant mutation authority or alter the runtime selector contract, but requires protected review.
- Backup restore remains destructive to local app state after password verification. The new staging layer only fixes file access; existing confirmation and backup validation must remain intact.
- Apple Files behavior varies by provider. The staging copy is moved off the main actor, uses 1 MiB cancellation checkpoints, and is deleted on every known terminal path; physical tests must still cover iCloud Drive and at least one File Provider extension, including cancellation during a 200 MiB copy.

## Learning storage

- Removing artificial caps means training data can grow. Writes remain atomic and naturally fail if iOS reports no space; the UI reports write failure. Governor may add a visible disk-pressure pause, but must not silently prune or merge the two games.
- V1 migration can recover exact positions by prefix. A V2 target is written only after an encode/decode verification in a sibling staging file, while the shared V1 file is left byte-for-byte intact. Old aggregate `completedGames` cannot be perfectly split if its old 40-record history had already discarded earlier per-game records; the migration intentionally counts only surviving game-typed records rather than inventing attribution.
- This is lightweight repertoire/sequence learning, not unrestricted neural training. It becomes observably adaptive but does not guarantee victory.

## 三国兵器

- V2 WEGO currently resolves movement/contact, not a complete casualty/end-state campaign. The candidate restores the large battlefield and playable turn loop; deeper combat remains a later feature.
- Old small-board code remains compiled for encrypted-history/protocol compatibility, but no current visible lobby or V2 negotiation UI renders it.

## Galgame blocker

The complete owner-supplied Monogatari R5 artifact is not present in main, GitHub Inbox or current attachments. Exact recovery is blocked; see `GALGAME_RECOVERY.md`. Do not claim the native Story Lab is the requested full Galgame.

## Stop conditions

- Patch apply failure, XcodeGen failure, Swift compile failure, any P0 touch/import/consent regression, checksum mismatch, database migration failure, or lost A10 telemetry => HOLD.
- No main merge, version bump, signing, IPA build or release from this submission.
