# VeilScreen R2 — INBOX-only delivery
- agent_id: veilscreen-capture-agent
- task_id: 20261114-ios26-replaykit-capture-r2
- base_main_sha: af3d823546c288169d19cb3033a6111977d28bd7
- mode: INBOX_ONLY
- predecessor: VeilScreen R1 Draft PR #232, supersedes R0 Draft PR #226
- scope: iOS 15+ ReplayKit Broadcast extension video capture; App Group + keychain AES-GCM ephemeral one-frame mailbox; off-main host polling; video consent UI; fail-closed capture routing
- status: DROPPED; Governor integration/testing pending
- guardrails: no production source, protocol, signing, version, workflow, main or IPA writes
- tests: Swift 6.2.1 Linux R2 core `-O` smoke PASS; 100-frame R1-v2 scheduling/reassembly PASS; iOS-only source parser PASS; plist syntactic parse PASS
- not_run: Apple SDK typecheck, provisioning/entitlements, extension install, system picker, two iPhones/real BLE, background test, XCTest, IPA

- 2026-11-15 compatibility amendment: both devices iOS 15; R2.1 corrects RPBroadcastSampleHandler override signature, explicitly tests route 15/16, adds IOS15_COMPATIBILITY.md. Original PR #236 remains Inbox-only.
