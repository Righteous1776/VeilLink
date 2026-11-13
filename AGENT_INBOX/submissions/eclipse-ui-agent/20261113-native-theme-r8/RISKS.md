# Risks / review blockers
1. R8 is a **theme correction** of R7, not a new visual brand. Do not merge R6/R7 own-palette design over R8 or restore obsolete on-board candidate/highlight overlays.
2. R7 local SwiftUI source has no full iOS compile; R8 custom props/trace must be typechecked with Xcode before any real-device claim.
3. R8 HTML uses visually approximate CSS tokens. Only actual SwiftUI `VeilAppearanceController` source controls the app; HTML screenshots are design previews, not proof of live in-app appearance.
4. Theme authorization: `plainline` is restricted experimental. ECLIPSE does not bypass restrictions.
5. Read-only replay board uses established Gomoku art constants; do not alter the interactive game board in main.
6. Current main has no R5 native real-time trace; nil metrics display as dashes. Never invent progress numbers or player hints.
7. Overlaps #197 (R6), #198 (R7), #193/#196 (controller), #187 (trace); Integration Governor must arbitrate. No direct product tree writes.
8. Owner ZIP contains full code and patch. This GitHub PR intentionally contains review docs only; references SHA-256 for content integrity.
9. Do not remove or misattribute still-vendored MIT engine code; this R8 scope has no search-engine changes.
