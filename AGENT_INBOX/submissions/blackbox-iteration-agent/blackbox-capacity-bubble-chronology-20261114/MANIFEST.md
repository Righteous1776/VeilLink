# VEILLINK Diagnostic Flight Recorder / five-night coverage revision

- agent_id: blackbox-iteration-agent
- task_id: blackbox-capacity-bubble-chronology-20261114
- status: DROPPED
- base_main_sha: af3d823546c288169d19cb3033a6111977d28bd7
- revision_date: 2026-11-14
- scope: bounded 512 MiB diagnostics, visible-bubble order metadata, rotation loss evidence, registry inventory and module hook API, explicit owner capture activation, pre-consent ring 512
- proposed_files:
  - VeilLink/Diagnostics/DiagnosticLogStore.swift
  - VeilLink/Diagnostics/VeilPreConsentBlackBox.swift
  - VeilLink/Diagnostics/RuntimeDiagnosticsBridge.swift
  - VeilLink/UI/ConversationViews.swift
  - VeilLink/UI/DiagnosticsLogView.swift
  - VeilLink/UI/OwnerConsoleView.swift
  - VeilLink/UI/VeilFeatureLibraryView.swift
  - VeilLinkTests/DiagnosticLogStoreTests.swift
  - VeilLinkTests/BlackBoxExportIntegrityTests.swift
  - VeilLinkTests/PreConsentBlackBoxTests.swift
- protected_surfaces: diagnostics local files, owner UI and pre-consent separation. NO wire protocol, SQLite schema, cryptography, private entitlements, signing, CI, version or release changes
- dependencies: SwiftUI / existing Foundation, ZIPFoundation, MetricKit; no binaries or new libraries
- known_overlaps: earlier diagnostics-agent preconsent task; PR #64/#66 instrumentation and protected UI
- source_prompt_summary: global future-proof module diagnostics and complete five-night owner debugging; prioritize no message plaintext and auditable data loss, improve in-app hooks without OS privilege bypass
- asset_grant: none, proposal text only
- verification: unified diff context replay against main PASS; Xcode XCTest/hardware/privacy benchmark NOT_RUN


## R3 capture coverage revision — 2026-11-14

- current_proposed_source_and_test_files: 14 (the prior list of 10 files above is superseded)
- additional_proposed_files:
  - VeilLink/Agent/Games/LocalAIGameController.swift
  - VeilLink/Transport/BLETransport.swift
  - VeilLink/App/VeilopolyMultiplayerBridge.swift
  - VeilLink/UI/GameLobbyView.swift
- scope_extension: native Gomoku/ECLIPSE and all seven local AI game reducers; BLE link lifecycle + sampled backpressure; Veilopoly secure-room traffic plus committed game reducer state; 14 arcade/story game launch boundaries
- constraints: no user chat body, BLE packet payload, private keys, Monopoly card bodies or complete save data; no true cross-app/system privilege
- R3_verification: 14-file unified patch (83+ hunks) context-matched against exact main. Apple Xcode/XCTest/device tests NOT_RUN; native-engine coverage is partial.
