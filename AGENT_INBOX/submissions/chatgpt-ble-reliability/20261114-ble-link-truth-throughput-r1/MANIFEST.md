# Agent Submission Manifest

agent_id: chatgpt-ble-reliability
task_id: 20261114-ble-link-truth-throughput-r1
base_main_sha: af3d823546c288169d19cb3033a6111977d28bd7
submission_path: AGENT_INBOX/submissions/chatgpt-ble-reliability/20261114-ble-link-truth-throughput-r1/
mode: INBOX_ONLY
status: DROPPED
asset_grant: none
proposed_paths:
  - VeilLink/Transport/BLELinkReliabilityPolicy.swift
  - VeilLink/Transport/BLETransport.swift
  - VeilLink/Transport/BLELinkSnapshot.swift
  - VeilLink/UI/NearbyView.swift
  - VeilLinkTests/BLELinkReliabilityPolicyTests.swift
  - VeilLinkTests/BLELinkSnapshotTests.swift
patch: PATCH.diff
validation: source snippets matched exact main at commit af3d823546c288169d19cb3033a6111977d28bd7; static-only, no iOS build
owner_request: Do not declare disconnected based on weak/near-failing signal; improve global BLE robustness.
