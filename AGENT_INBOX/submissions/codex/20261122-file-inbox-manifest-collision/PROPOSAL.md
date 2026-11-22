# Preserve imported files named record.json

## Decision

Prioritize a durable-copy defect over the outdated version in the README and missing VoiceOver feedback on the PIN screen. The Files picker can report success while the local payload has already been replaced. An affected user needs the original file to recover it.

## Failure path

Import a short JSON file named `record.json`. The inbox copies it under that name in a new pending folder, checks its SHA-256, then atomically replaces the same file with the record metadata. The folder is published successfully. A later list ordinarily omits the record because the metadata size differs from the recorded payload size. The provider original survives. Filename trimming and case-insensitive filesystems widen the set of affected names.

## Proposed behavior

Compare the final sanitized basename with the reserved manifest name, ignoring case. Use `content.json` for a colliding payload within its own UUID folder. Keep the provider name in the display record and retain the existing kind detection. The manifest write now requires a fresh path, so a filesystem alias that escapes name comparison fails before publication. The pending-folder cleanup and final directory rename still bound the operation.

The accompanying XCTest imports three filename variants through the existing staging API, releases the staged copy, reopens the record, compares its bytes, verifies its digest and removes it.
