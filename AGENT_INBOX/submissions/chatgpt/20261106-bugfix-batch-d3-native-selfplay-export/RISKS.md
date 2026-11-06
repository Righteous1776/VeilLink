# D3 risks and governance

- INBOX_ONLY. Do not apply PATCH.diff to main, self-merge, dispatch CI, change version, publish IPA.
- Potential UI file-level collision: PR #129 import staging (GameLobbyView importer and temp lifecycle), and any ongoing Games/UI lane. Governor resolves; this lane does not.
- Other pending PRs: #137, #138, #139, #140 still unapplied. Preserve their patches and independent owner/governor arbitration. PR #140's file picker and staging lifecycle may interact with the app-level temporary-file cleanup.
- Serialization remains @MainActor and encodes the full unbounded archived Database. Very large self-play data could stall the UI or exhaust RAM; stress test and optimize asynchronously before promoting on low-memory devices.
- ShareSheet temporary URL is removed on sheet dismissal; test saving to Files and sharing to other apps before accepting.
- Native archive export is a *structured .vltrain.json dataset*, not standalone SGF/CSV. Every game has ordered moves, result and finish time; this is not a new game protocol or weight training.
- Existing archive does not verify a user-overwritten file's full original game semantics at export time; corruption is handled by store's load/recovery guards. Training engine and stored records are not altered by this proposal.
- Xcode/XCTest/device NOT_RUN. Missing evidence must not be reported as PASS.
