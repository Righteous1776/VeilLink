# VeilLink Entertainment Universe 90 — proposal

See `FEATURE_CATALOG_90.md` for full numbered E01–E90 experiences and technical cores (9 series × 10). Distinct from existing Gomoku, Xiangqi, Ludo, Guandu Tactical, artillery, light-trail, magnetic hockey, realtime rhythm/platformer and Prism Rift 3D.

## Implemented candidate

E01 `VeilStoryEngine.swift` is a completely local, deterministic, bounded narrative state machine. Includes story graph validation; condition-gated choices; items, flags and score; 128-turn cap; atomic invalid-choice rejection; deterministic history replay; 3 self-authored stories (rainy night train, observatory, island lighthouse). Foundation-only engine. The iOS 15 SwiftUI `VeilStoryLabView.swift` provides standalone story selection, choices, endings and replay. No GameLobby/ToolCenter integration or app startup hook. `VeilStoryEngineTests.swift` adds 10 XCTest cases.

Candidate source files are in this Inbox under `FILES/`; `PATCH.diff` is a proposed new-file patch. Governor should verify patch and import only via isolated integration branch.

## Phases

Wave0: first contain severe iOS 15 gesture, first-sign and Keychain continuity problems. Wave1: E01 narrative playable sample and editor foundations. Wave2: independent deterministic roguelite/tower defense/science games. Wave3: creators, audio & video with explicit user file selection and license checks. Wave4: same-device collaboration, then only after protocol review, BLE/E2EE multiplayer. Wave5: long-life cross-world systems.

## Security and boundaries

No main change, wire v4, SQLite v10, identity, A9/A10 governance, Keychain, CI workflow, version, signing or release edits. No binaries or model weights. No implicit device media/user chats. Do not represent design-only features as shipped or accessible. On iPhone7, prioritize a low-resource 30fps tier and accessible native buttons.
