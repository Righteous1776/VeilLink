# RISKS / OVERLAP

**Major:** Existing unresolved physical iPhone7 signing/Keychain legal consent issue, plus PR #64 root particle global gestures, PR #65 per-game touch handlers and PR #66 UIWindow telemetry recognizer. No production navigation should be changed now.

**Review:** Existing GameLobby, ToolCenter, MiniGame, protocol, SQLite v10 and A9/A10 code remains unchanged. Mission Control #67/#68 are separate candidates; do not import overlapping type names or navigation changes without arbitration.

**Artifact scope:** Full candidate code/patch only in downloaded ZIP; this GitHub PR contains a limited design record, not a functional implementation. Do not merge or release it as though features were added.

**Validation:** Linux tests do not prove SwiftUI compiles on macOS or iOS15; UI, gesture and thermal validation pending. Textbook simple 12x12 dungeon is a prototype, not a shipped large-scale game. No BLE multiplayer code implemented.

**Privacy/legal:** No personal data, decrypted conversations, third-party media, binary resources, signing material or model weights. Future synchronization and user-imported media require explicit opt-in and licensing.
