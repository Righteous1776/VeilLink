# VeilScreen R1 / UI + Control Workflow / AGENT-DROP

- agent_id: veilscreen-ui-agent
- task_id: 20261114-invite-viewer-r1
- base_main_sha: `af3d823546c288169d19cb3033a6111977d28bd7` / VeilLink V29.1 Build 67
- mode: INBOX_ONLY
- submission_path: `AGENT_INBOX/submissions/veilscreen-ui-agent/20261114-invite-viewer-r1/`
- status: **DROPPED / GOVERNOR TRIAGE REQUIRED**
- scope: explicit invite/accept/decline and sender consent UI; receiver view and zoom; handshake state machine; bounded low-priority BLE video sender; R1 frame codec; test-only preview gallery
- intended product files: VeilLink/ScreenShare/VeilScreenShareWire.swift, VeilLink/ScreenShare/VeilScreenSessionMachine.swift, VeilLink/ScreenShare/VeilScreenSessionWorkflow.swift, VeilLink/ScreenShare/VeilScreenBLEScheduler.swift, VeilLink/ScreenShare/VeilScreenFrameEncoder.swift, VeilLink/UI/VeilScreenShareViews.swift, VeilLinkTests/VeilScreenR1Tests.swift, VeilLink/UI/VeilScreenPreviewGallery.swift
- forbidden changes: main, app source, actual wire protocol migration, key management, version/build, signing, IPA and workflows
- note: full source is inside `FILES/` and advisory `PATCH.diff`; no direct product edit.

Review precedence: This R1 candidate supersedes R0 wire proposal from PR #226 if/when the Governor selects it. Do **not** apply both R0 and R1 copies to the product tree.
