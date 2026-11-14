# D2 risks
- Both user permissions and valid current move must exist. Making the permission visible is not equivalent to executing every game suggestion.
- Existing `AgentGameContextBroker` deliberately has no executable suggestions for several mini-games and in compact-safe mode; UI must not advertise blanket support.
- Pending game recovery PR #130 changes `MiniGameViews.swift`, not this proposed sheet, but behavioral overlap exists. Governor arbitration required.
- No control-plane default changed, no persistence schema migration, no full branch integration, no BLE workaround claimed.
- No Apple SDK/XCTest or physical-device verification. Under INBOX_ONLY this is only a patch proposal.
