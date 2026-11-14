# VeilLink 大富翁 & 全局 BLE 连接稳定性修复 / Agent Drop

- agent_id: chatgpt
- task_id: 20261114-veilopoly-ble-link-stability
- mode: INBOX_ONLY
- status: DROPPED
- base_main_sha: af3d823546c288169d19cb3033a6111977d28bd7
- created_at: 2026-11-14
- submission_path: AGENT_INBOX/submissions/chatgpt/20261114-veilopoly-ble-link-stability/
- scope: Veilopoly game-liveness / shared BLE central and peripheral TX queue flow control
- proposed_files: 7 (3 tests), full contents under FILES/, exact-context unified patch in PATCH.diff
- protected_surfaces: BLETransport.swift; BLELinkReliabilityPolicy.swift
- dependencies: Governor review; macOS iOS SDK build and simulator XCTest; two-device BLE acceptance
- known_overlaps: PR #201 foreground restore; prior BLE reliability Inbox lane; Veilopoly PR #184 and #188; no automatic resolution performed
- source_prompt_summary: Fix false disconnection in Veilopoly; no premature offline state due to fading RSSI or game inactivity; improve global BLE transport resilience; stage actual code/tests in Inbox

## Build and publication
Only Inbox files were committed to this agent branch. No direct product edits, release, signing, workflow dispatch, wire-format or A9/A10 changes.
