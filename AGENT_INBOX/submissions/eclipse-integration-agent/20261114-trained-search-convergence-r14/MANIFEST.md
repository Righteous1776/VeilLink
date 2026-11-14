# [AGENT-DROP] ECLIPSE R14 — multi-Agent trained native convergence

owner_goal: 把并行 Agent 的有效研究成果去重集成到 ECLIPSE
agent_id: eclipse-integration-agent
task_id: 20261114-trained-search-convergence-r14
base_main_sha: eb487a1901c0ffddfb38b80b9fb56f6d7d749ba0
mode: INBOX_ONLY
status: COMPLETE_REVIEW_DROP_NOT_PRODUCT_INTEGRATED
product_patch: PATCH.diff
existing_product_files: 4
new_product_files: 17
total_product_paths: 21
product_patch_chars: 297371
all_paths_exact_main_preimage_replay: PASS (21/21; 30 existing-file hunks + 17 add-file sections)
full_git_checkout_apply: NOT_RUN
Apple_Xcode_XCTest: NOT_RUN
iPhone_iPad_runtime_and_thermal: NOT_RUN
training_model_frozen_blob: 4e73cc1910820324487d9350194cfb5562a8439f
integration_native_kernel_blob: 36788e0672a9fffcb27642c3b8d57c858b72d70f
product_patch_blob: d1902db2148eba6a3834d5ca4ac6b7b7c50df852
unchanged_model_weight_count: 48 trained trees / 1348 nodes (from #209)
frozen_training_sample_unit: 1848616 D4-deduplicated board-action rows, NOT completed games
source_prs: #209 #213 #214 #208
tests_in_patch: EclipseHorizonR12Tests.swift, EclipseIncrementalThreatIndexR13Tests.swift, EclipseR14NativeIntegrationTests.swift
experiments_default_off: r12HorizonQuiescence, r13IncrementalThreatIndexEnabled
player_board_visualization_default_off: true
legacy_JSCore: retained_on_disk_and_in_bundling_but_not_selected_by_R14_controller
version_build_release_authority: NONE
overlap: #193 #196 #199 #206 #207 #210 #211 #212 and R8/R9 UI drafts; no sibling PR merged

Owner note: Github PR merges this submission to Inbox only. Product patch needs a formally authorized Integration Governor promotion branch, actual Xcode build/XCTest and rollback review.
