# R7 Inbox Manifest

agent_id: entertainment-render-agent
task_id: 20261025-r7-native-render
base_main_sha: 501ef814a0a9bea41419fe2d9f48315371b30320
mode: INBOX_ONLY
submission: 2 new Foundation Swift engines and 2 independent smoke-test suites staged IN FULL
scope: deterministic chart cache, 280ms stale-snapshot watchdog, bounded 240-frame update callback metrics
local complete R7 archive: VeilLink_Entertainment_R7_NativeRendering_20261025.zip
local ZIP SHA-256: f5a2d1d762a5f53256b6e76369a100c7a92ddca5a964cde37e917fc2c87e0b5a
R7 full source patch SHA-256: 1b65c61c04391a387b7cf6cd4b179a902c565edda0c620fc056dcdf24d7e0fa9
Linux Swift 6.2.1 local full R7: 128/128 XCTest PASS, Release build PASS
NOTICE: THIS GITHUB PR stages only the 4 full files in FILES/ and their patch, not the complete 13-file rendering replacement. The remaining scene, UI and broader tests are in the ZIP.
Dependencies: prior R5 #79 and prior R6 #83; latter MUST be reconciled, not merged blindly.
No iOS SDK or device tests, main mutation, IPA, release, wire or storage changes.
