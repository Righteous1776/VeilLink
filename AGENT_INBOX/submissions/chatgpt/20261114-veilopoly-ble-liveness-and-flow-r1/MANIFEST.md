# Agent Inbox Submission
agent_id: chatgpt
task_id: 20261114-veilopoly-ble-liveness-and-flow-r1
base_main_sha: af3d823546c288169d19cb3033a6111977d28bd7
submission_path: AGENT_INBOX/submissions/chatgpt/20261114-veilopoly-ble-liveness-and-flow-r1/
status: DROPPED
scope: Veilopoly heartbeat/UI status; shared BLE GATT stall, flow control, and link recovery
proposed_files:
- VEILOPOLY_DEV/Veilopoly/Sources/VeilopolyNet/RoomLinkPolicy.swift
- VeilLink/App/VeilopolyMultiplayerBridge.swift
- VeilLink/Transport/BLETransport.swift
- VeilLinkTests/BLELinkReliabilityPolicyTests.swift
- VEILOPOLY_DEV/Veilopoly/Tests/VeilopolyNetTests/RoomLinkPolicyTests.swift
- VeilLinkTests/VeilopolyInvitationBridgeTests.swift
validation: Anchored exact-source diff checked against main at staging; Apple SDK/XCTest/physical dual-device testing pending.
asset_grant: none
