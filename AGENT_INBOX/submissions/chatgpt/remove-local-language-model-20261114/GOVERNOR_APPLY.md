# Governor integration steps (not executed)

**Product authorization:** Owner requested native language model removal. This agent remains INBOX_ONLY: no code in this submission has been applied to product source. Owner/Governor must review the deletion and branch dependency graph.

## Atomic operation on a fresh Governor integration branch
```bash
git fetch origin main
git switch -c integration/remove-local-language-model-20261114 origin/main

# Copy the Inbox PATCH.diff into the integration workspace; path is relative
# to repository root in the agent-drop branch after checking it out separately.
git apply --check PATCH.diff
git apply PATCH.diff

# Remove every model-only source, test, workflow, script and the binary itself:
git rm -- \
  "VeilLink/Resources/LocalAI/Vertex-0.6-35M-Instruct-Q4_K_M.gguf" \
  "VeilLink/Resources/LocalAI/README.md" \
  "VeilLink/Resources/LocalAI/LICENSE-APACHE-2.0.txt" \
  "VeilLink/Resources/LocalAI-THIRD-PARTY-NOTICES.txt" \
  "VeilLink/Agent/Language/Vertex35MChatRuntime.swift" \
  "VeilLink/Agent/Language/Vertex35MChineseQualityGate.swift" \
  "VeilLink/Agent/Language/Vertex35MModelIntegrityGate.swift" \
  "VeilLink/Agent/Language/LingCoreChatOnlyBoundary.swift" \
  "VeilLink/UI/LingCoreTinyChatView.swift" \
  "VeilLink/Agent/Language/LlamaInferenceEngine.swift" \
  "VeilLink/Agent/Language/LlamaLocalTextModelRuntime.swift" \
  "VeilLink/Agent/Language/LlamaRuntimeConfiguration.swift" \
  "VeilLink/Agent/Language/LlamaCancellationGate.swift" \
  "VeilLink/Agent/Language/LocalModelCatalog.swift" \
  "VeilLink/Agent/Language/LocalModelManager.swift" \
  "VeilLink/Agent/Language/QwenPromptFormatter.swift" \
  "VeilLinkTests/Vertex35MChineseQualityGateTests.swift" \
  "VeilLinkTests/Vertex35MModelIntegrityGateTests.swift" \
  "VeilLinkTests/Vertex35MOnDeviceSmokeTests.swift" \
  "VeilLinkTests/LingCoreChatOnlyBoundaryTests.swift" \
  "VeilLinkTests/RealLocalInferenceSmokeTests.swift" \
  "VeilLinkTests/LocalModelCatalogTests.swift" \
  "VeilLinkTests/QwenPromptFormatterTests.swift" \
  "scripts/build-llama-ios15.sh" \
  "scripts/fetch-qwen-model.sh" \
  "scripts/prepare-vertex35m-ios.sh" \
  "scripts/make-vertex35m-project.py" \
  "scripts/verify-vertex35m-model.py" \
  ".github/workflows/lingcore-vertex35m-validation.yml"
```

1. Do not run `git rm` before confirming the 29 paths in DELETE_MANIFEST.txt and their owners.
2. Keep `VeilLink/Agent/Language/VeilTalkLiteRuntime.swift`, `LocalTextModelRuntime.swift`, `LocalTextModelCoordinator.swift`, `LocalTextModelManifest.swift`, `MockLocalTextModelRuntime.swift`, `AgentCoordinator.swift`, `AgentHomeView.swift` (modified only), LingCore main chat, all BLE and encrypted messaging.
3. **Do not remove** `VeilLink/Resources/A10UltraM5/**`, `VeilLink/Resources/AgentModels/game_policy_ranker_v4.vlpol`, Gomoku/Chinese chess game AI weights, or unrelated models in uploads.
4. Ensure no generated `project.vertex35m.yml` or `Vendor/llama.xcframework` is bundled in the final IPA. Both may be untracked build leftovers; remove only from isolated build output, never use force-clean on developer data.
5. PR #194 native-llama stability proposal becomes obsolete under removal and must **not** be integrated. PR #195 proposes `LingCoreTinyChatView.swift` changes: discard that file's changes only and preserve its nonoverlapping flag/chat fixes, with Governor arbitration.
6. Check both `VeilLinkTests` and `VeilLinkUITests`; run new `LocalLanguageModelRemovalTests` and existing non-LLM tests.
7. Build iOS15 normal app. Assert the IPA has **zero** `*.gguf`, no `llama.xcframework`, no model experiment chat entry; verify VeilTalk Lite still responds.
8. Commit only after product tests pass; do not publish an IPA without the Owner's release grant.

**Git retention:** This removes 29 files from the current tree, including a ~27.9 MiB GGUF. Existing Git history still contains the old blob; repository size on disk may not fall until history maintenance. Do NOT rewrite shared Git history as part of this integration.
