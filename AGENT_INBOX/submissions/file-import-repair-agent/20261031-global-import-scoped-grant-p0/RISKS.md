# Risks & overlaps

- Scope acquisition timing is a plausible bug, not a confirmed universal root cause. Other window-specific .fileImporter routing, SwiftUI sheet/overlay or Files-provider permissions may still fail.
- Scope may be false for ordinary app-local files; do not treat false alone as an error.
- If async worker outlives cancelled parent, make sure defer runs only after worker completes; test cancellation and lease safety on actual devices.
- Overlap with PR #92/#93/#94/#95 (file-import/backup staging); Governor arbitration required.
- No mutation of schema, transport, identity or Owner gate; no production publication.
