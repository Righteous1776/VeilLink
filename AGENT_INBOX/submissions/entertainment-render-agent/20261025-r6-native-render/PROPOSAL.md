# R6 Native Graphics Governor Intake

BASE MAIN: `501ef814a0a9bea41419fe2d9f48315371b30320`. Mode: `INBOX_ONLY`.

Nine complete add-only proposed source/test files are staged under this submission's FILES and mirrored by PATCH.diff. None is applied to the VeilLink product source.

- Architecture: Foundation model separate from UIKit/SpriteKit visual render and SwiftUI controls.
- No stretched canvas: 390×600 virtual aspectFit; screen-coordinate mapping with letterbox exclusion.
- R5 dependency: VeilRhythmLiveConductor and VeilRhythmExpedition (draft PR #79, not main); integrate those first on Governor branch.
- Native iOS15 experiment: UIViewRepresentable SKView, noninteractive stage, SwiftUI buttons; 5 pooled notes, requested 30 fps for legacy tier; no claimed measured device fps.
- Rendering stays bounded and read-only; scoring driven only by monotonic host tap times.
- Do NOT change main, project.yml, release/signing, BLE, Keychain, SQLite, A9/A10 or GameLobby in this Inbox.
- No Asset Drop; artwork is code-generated primitives only.
- Integration priority: P0 gesture/consent #64/#65/#66, R5 source dependency #79, then R6 native candidate + macOS build/simulator/physical iPhone7.

`R6_RENDER_ARCHITECTURE.md`, QA and simulator recipe are delivered in the user-facing ZIP, not live product changes.
