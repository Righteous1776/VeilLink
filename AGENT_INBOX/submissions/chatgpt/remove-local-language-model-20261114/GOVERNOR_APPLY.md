# Governor integration steps (not executed)

**Product authorization:** Owner requested native language model removal. This agent remains INBOX_ONLY: no code in this submission has been applied to product source. Owner/Governor must review the deletion and branch dependency graph.

## Atomic operation on a fresh Governor integration branch
```bash
git fetch origin main
git switch -c integration/remove-local-language-model-20261114 origin/main

# Copy the Inbox PATCH.diff into the integration workspace; path is relative
# to repository root in the agent-drop branch after checking it out separately.
git apply --check PATCH.diff
# Applies the 6 amended/added files and 28 text-file deletions ATOMICALLY.
git apply --index PATCH.diff

# The sole binary is intentionally excluded from text-only Inbox patch.
git rm -- VeilLink/Resources/LocalAI/Vertex-0.6-35M-Instruct-Q4_K_M.gguf
git diff --cached --check
git diff --cached --stat
```

1. Confirm all 29 paths in DELETE_MANIFEST.txt. The text patch deletes 28 paths; `git rm` above handles the single 29,203,168-byte binary. Never run `git rm` for already-deleted paths.
2. Keep `VeilLink/Agent/Language/VeilTalkLiteRuntime.swift`, `LocalTextModelRuntime.swift`, `LocalTextModelCoordinator.swift`, `LocalTextModelManifest.swift`, `MockLocalTextModelRuntime.swift`, `AgentCoordinator.swift`, `AgentHomeView.swift` (modified only), LingCore main chat, all BLE and encrypted messaging.
3. **Do not remove** `VeilLink/Resources/A10UltraM5/**`, `VeilLink/Resources/AgentModels/game_policy_ranker_v4.vlpol`, Gomoku/Chinese chess game AI weights, or unrelated models in uploads.
4. Ensure no generated `project.vertex35m.yml` or `Vendor/llama.xcframework` is bundled in the final IPA. Both may be untracked build leftovers; remove only from isolated build output, never use force-clean on developer data.
5. PR #194 native-llama stability proposal becomes obsolete under removal and must **not** be integrated. PR #195 proposes `LingCoreTinyChatView.swift` changes: discard that file's changes only and preserve its nonoverlapping flag/chat fixes, with Governor arbitration.
6. Check both `VeilLinkTests` and `VeilLinkUITests`; run new `LocalLanguageModelRemovalTests` and existing non-LLM tests.
7. Build iOS15 normal app. Assert the IPA has **zero** `*.gguf`, no `llama.xcframework`, no model experiment chat entry; verify VeilTalk Lite still responds.
8. Commit only after product tests pass; do not publish an IPA without the Owner's release grant.

**Git retention:** This removes 29 files from the current tree, including a ~27.9 MiB GGUF. Existing Git history still contains the old blob; repository size on disk may not fall until history maintenance. Do NOT rewrite shared Git history as part of this integration.
