# PROPOSAL — 30 MB Chat-Only Model for LingCore

## 1. Candidate selection
The user requested a *strictly conversational* offline small model, not a new A9/A10/A13 decision engine.

Preferred candidate: [Vertex-0.6-35M-Instruct-GGUF](https://huggingface.co/VertexResearch/Vertex-0.6-35M-Instruct-GGUF), Q4_K_M (~29.2 MB). This is a 33.9M parameter, ChatML, Qwen3-architecture **instruct/chat** model, 1024-token context, Apache-2.0. Source model: https://huggingface.co/VertexResearch/Vertex-0.6-35M-Instruct. It is English-centric, weak on factual accuracy, prone to repetition, not safety-tuned. Do not market as a capable assistant, especially for Chinese.

Alternative: Q5_K_S around 30.1 MB or Q8_0 37.2 MB if quality improves in real device tests. Compare identical prompts before choosing. All counts refer to weight-file sizes, NOT total IPA or RAM usage.

Rejected as default:
- karpathy TinyStories 110M, PS2-LLM ~30 MB Q4 PSNT: a story-completion model in a custom PSNT format, not an instruct-chat model.
- Sentient-NPC ~32.4 MB .keras: an English Skyrim single-turn NPC model; no LICENSE file found in current root and requires conversion; cannot assume redistribution rights.

## 2. HARD authority boundary
The tiny model exists as an independent *chat-only* backend and never replaces LingCore, A9 governor, A10 cognition, A13, game decision engines, host action/control plane, security, encryption, identity, transport, storage, or diagnostic code.

Permitted input: user text deliberately entered in the dedicated tiny-chat view; maximum 512 characters, six short conversation messages, no automatic contextual enrichment.
Permitted output: visible text tokens to that chat view, max 96 new tokens by default.
Denied: AgentToolRouter, bindIntegration, toolExecutor, app state mutation, database reads/writes, game moves, cross-device message sends, network requests, file reads, privileged device metadata, model-directed tool calls, automated actions, untrusted output routed as a command.
No silent access to current chats or peers. A literal '/game move' typed in this chat remains text only.

The staged Swift `LingCoreChatOnlyBoundary` has no AppModel/AgentCoordinator/controller dependencies and always sets localContext=nil and visualContext=nil. A caller must never give it a privileged runtime or expose the resulting text as a tool command. Model responses are not trusted instructions.

## 3. Integration sequence (not yet executed)
1. Add/verify an iOS-capable `llama.cpp` build with architecture/Qwen3 support. Existing core `project.yml` explicitly excludes LlamaInferenceEngine and LlamaLocalTextModelRuntime; this is an actual build blocker. Do NOT globally enable these dormant sources or switch production factory without dedicated tests.
2. Pin selected upstream GGUF revision, exact byte count, SHA-256, license attribution and tokenizer/chat template. Import model into an opt-in dedicated app resource or user-installed sandbox path, never into Inbox/Git history. Validate full SHA-256 before load; fail closed on mismatch.
3. Create a minimal `Vertex35MTextRuntime : LocalTextModelRuntime` that calls only llama.cpp text decode and embeds no tool/access calls; separate it from `AgentCoordinator`. It must use the GGUF ChatML template and context <= 1024, clamp output, cancellation, timeouts and memory limits.
4. Add a **separate** `LingCoreTinyChatView` with explicit enable, correct label '离线微型聊天（实验）', privacy notice, no quick-action buttons, no app tools, no auto-loaded message context. The existing privileged AgentChatView and its toolExecutor must NOT be reused.
5. Run native simulator and physical device smoke tests, check real Chinese and English exchanges, consistency, prompt-injection resistance, overload, thermal and fail-closed behavior. Only then request governor promotion.

## 4. Deployment gates
- Chat-only decision: PASS only if actions, A9/A10/A13/governance, game moves, and DB mutations are provably impossible from this path.
- Model/backend: PENDING (no GGUF included, no production inference enabled).
- License/attribution and artifact integrity: PENDING verification of exact downloadable quantized file, including original trained model license.
- iOS build/XCTest: NOT_RUN.
- Performance claims: none; no invented tokens/s or memory benchmark.
- Release and IPA: DENY.
