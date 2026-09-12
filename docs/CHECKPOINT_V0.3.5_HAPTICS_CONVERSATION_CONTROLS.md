# V0.3.5 Haptics & Conversation Controls

VeilLink 0.3.5-dev build 11 extends the V0.3.4 visual identity with tactile feedback and local conversation-state controls while keeping wire Protocol 4 unchanged.

## Tactile feedback

`Core/HapticEngine.swift` provides one centralized, preference-backed haptic layer. Haptics are enabled by default, can be disabled, and expose subtle / balanced / strong intensity presets. The engine refuses to play while the app is not active. Send, authenticated delivery resolution, inbound message arrival, pairing decisions, connection actions, image pause/resume/cancel, conversation pin/read actions and destructive local-history actions use semantic feedback rather than arbitrary vibration.

## Conversation controls

Schema V8 adds `conversations.is_pinned`. Conversation queries sort pinned rows before ordinary recency. Existing `unread_count` is now active: a newly persisted inbound message increments unread exactly once, outgoing messages do not, and opening an active chat resets the count. Users can also explicitly mark a conversation read or unread. Conversation rows expose pin state and unread badges; iOS 15 swipe actions and context menus toggle both states. The phone Chats tab and iPad sidebar aggregate unread counts without changing peer-visible state.

Long-pressing a text message now includes a local Copy action. Reply envelopes copy only their newest reply text instead of the internal compatibility envelope.

## Local CI simulation

`scripts/local-ci-sim.sh` mirrors all GitHub steps that can be validated without macOS/Xcode: project/workflow manifests, Info.plist metadata, full Swift parse, Linux-compatible core typecheck, an executable BLE/reply behavior harness, a stubbed haptic API-shape typecheck, shell syntax, iOS 15 API guard, Schema V7→V8 migration smoke, IPA Payload layout smoke and whitespace checks. It explicitly does not claim to replace XcodeGen, `xcodebuild`, XCTest on an iOS Simulator, or the real unsigned iphoneos Release build.

Protocol: 4 (unchanged)
Schema: V8

Current source self-audit: 44 Swift files, 87 XCTest methods declared. The 87 tests still require Xcode/macOS to execute as XCTest.
