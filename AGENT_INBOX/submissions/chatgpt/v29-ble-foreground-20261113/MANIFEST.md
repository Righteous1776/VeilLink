# V29 BLE foreground wanted-peer restoration (restricted proposal)
agent_id: chatgpt
task_id: v29-ble-foreground-20261113
source_branch: main
source_sha: eb487a1901c0ffddfb38b80b9fb56f6d7d749ba0
base_main_sha: eb487a1901c0ffddfb38b80b9fb56f6d7d749ba0
mode: INBOX_ONLY
status: DROPPED
related_issue: 185
scope: BLE foreground restoration only; protected lane requires Governor permission
proposed_files:
- VeilLink/Transport/BLETransport.swift
- VeilLink/Transport/BLELinkReliabilityPolicy.swift
- VeilLinkTests/BLELinkReliabilityPolicyTests.swift
patch: PATCH.diff
