# [AGENT-DROP] Remove native GGUF language model family from VeilLink

## Owner request (2026-11-14)
"这一次把那个AI模型给删了，没用。" Context: native llama/Qwen/Vertex experimental local chat and related crashes. This proposal removes *language* model weights and native runtime, NOT A10 game/governance AI or network services.

## Exact code facts on main
- 29,203,168-byte GGUF lives at `VeilLink/Resources/LocalAI/Vertex-0.6-35M-Instruct-Q4_K_M.gguf`; base `project.yml` already excludes the binary. So **standard V29 IPA size need not change**, while the special model IPA would lose ~27.9 MiB of weight.
- Qwen3-0.6B Q4_0 descriptor requires >=400MiB but its GGUF is not in main. Its catalog/manager and llama.cpp native code are excluded in standard `project.yml`, yet an experimental build pipeline can opt them in.
- Dedicated `VERTEX_CHAT_ONLY` path exposes a micro chat toolbar entry in `AgentHomeView`, `LingCoreTinyChatView`, `Vertex35MChatRuntime`, experimental native project scripts and dedicated macOS CI. Removing only the binary leaves broken experiment UI/CI and hidden loading paths.
- Production Core's `VeilTalkLiteRuntime` is model-free and retains local commands/diagnostics via AgentCoordinator; it is NOT a GGUF model.

## Proposed atomic removal
1. Set `LocalTextModelRuntimeFactory.make` unconditionally to `VeilTalkLiteRuntime`, with `backendName="VeilTalk Lite"` and `isRealLocalInferenceCompiled=false`, even if some future transitive dependency exposes `canImport(llama)`. Eliminate `REAL_LOCAL_AI_REQUIRED` compiler failure branch.
2. Remove optional Vertex toolbar entry from `AgentHomeView`, while preserving AgentChatView and video/tools buttons.
3. Fix explanatory text in AgentCoordinator and VeilTalk Lite so they no longer promise a separate local GGUF experimental AI.
4. Remove model-only 29 tracked files listed exactly in `DELETE_MANIFEST.txt`: GGUF (binary), its pinned metadata/license/notices, Vertex and Qwen native inference sources, experimental chat UI, test cases that require those models, model fetch/build/verify scripts, and experimental GitHub Actions workflow.
5. Update `project.yml` to remove stale exclusions after their source files have been deleted; preserve all non-language neural/game assets and unrelated resource declarations. New tests reject bundled old GGUF and verify model-free runtime.
6. The binary itself is NOT in the text patch because Inbox forbids binary resources. The 29-file removal is a **mandatory separate git rm operation in the same Governor integration commit**, not a silently completed action. Detailed sequence in `GOVERNOR_APPLY.md`.

## What must survive
- `VeilTalkLiteRuntime`, `LocalTextModelRuntime`, `LocalTextModelCoordinator`, `LocalTextModelManifest`, `MockLocalTextModelRuntime` and AgentCoordinator's local tools, chat, governance, BLE and user data.
- A9/A10 game decision infrastructure, `VeilLink/Resources/A10UltraM5/**`, `VeilLink/Resources/AgentModels/game_policy_ranker_v4.vlpol`, Gomoku and chess engine weights/training packages.
- Linked other language API work, if any, is separate from native GGUF; this proposal does not remove remote-network features or APIs.

## Conflict direction
PR #194 (`llama` pointer lifetime stabilization) is **SUPERSEDED by removal** and should not be integrated. PR #195 flag/chat display Inbox proposed changes to `LingCoreTinyChatView.swift`; discard only that path when deleting this experimental screen. PR #192 diagnostic repair and #201 BLE recovery remain relevant.
