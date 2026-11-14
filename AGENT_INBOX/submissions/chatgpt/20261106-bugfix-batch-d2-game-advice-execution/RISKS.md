# D2 risks / boundaries

- INBOX_ONLY: no direct product file write, merge, main changes, IPA, CI dispatch or new protocol.
- Prior PR #139 modifies Game UI/logic and PR #138 potentially runtime startup; note potential interaction with current-session reconstruction and suggestion computation. Governor owns arbitration.
- Agent permission remains off by default, opt-in persisted by preexisting local UserDefaults behavior; consent scope is per-device global, not per-game. Review UI text and existing Control Center wording.
- New synchronous refresh fetches all persisted messages; large chat history could stall UI, so stress test before accepting. A future indexed session fetch would be preferable but may touch DatabaseStore/protected schema.
- A recommendation may legitimately be absent if it is not the local turn, if device compact safe mode is active, or if the current native engine has no valid move. Do not promise universal advice.
- Language model analysis output remains untrusted prose, never passed to game transport.
- Xcode/XCTest/device verification NOT_RUN. Do not label this as completed runtime bugfix until integrated and tested.
