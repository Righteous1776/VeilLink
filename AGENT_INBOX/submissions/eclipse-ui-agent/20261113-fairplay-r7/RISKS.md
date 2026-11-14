# R7 risks / overlap / nonclaims

- This PR stages REVIEW DOCS ONLY; all implementation source and real 25 KB full product PATCH.diff are in an owner's local ZIP, with byte checksums in MANIFEST. Do not claim shipped code or an app update.
- Overlap with #197 ECLIPSE R6: earlier R6 suggested on-board spatial hints, which the owner now REJECTS. R7 supersedes those UI suggestions. Governor must not combine obsolete overlays.
- Overlap with #193/#196 R5 (Gomoku controller / telemetry), #187 Thinking Studio, #186/#190 tactical search. No self merge.
- Current main has no native live depth/nodes/PV. R7 intentionally shows '—', with only genuine isAIThinking/last decision elapsed. Calling animated abstract graph a true PVS visualization would be inaccurate.
- Replay uses existing local match journal, available only when stable and validated; no replay when disk is missing, corrupt, restored inconsistently, or match ongoing.
- Current UI patch is validated against synthetic known context, NOT a cloned full main; Xcode SwiftUI compilation unavailable in this Linux environment.
- Fair-play may require more restrictions in competitive multiplayer; R7 is scoped to local Gomoku and intentionally defaults to the stricter no-hint behavior.
- Original ECLIPSE avatar does not reuse Grok video/GIF resources; other games are untouched.
- No product-tree modifications or private user history included. Preserve existing third-party license records for still-shipped components.
