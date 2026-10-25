# R3 risk review
- The GITHUB submission is intentionally partial (ByteRange parser and its tests plus contract); full binary/Swift host sources remain in owner's exact ZIP, **not merged**.
- On iOS15 custom WKURLSchemeHandler may have different Range/cancellation/AVFoundation behavior than simulated; HTTPURLResponse on non-http schemes untested with Apple SDK.
- Custom-origin localStorage probe only tests current-session write/read, not storage durability across relaunch; no false persisted-save guarantee.
- iOS SDK Swift/WebKit typecheck and iPhone7 playback, memory, touch and process-recovery tests are still pending.
- GameLobby/project.yml changes overlap existing other feature lanes; Governor only decides integration order.
- Do not modify main, workflows, signing, identity, BLE, database or releases; no IPA dispatch.
