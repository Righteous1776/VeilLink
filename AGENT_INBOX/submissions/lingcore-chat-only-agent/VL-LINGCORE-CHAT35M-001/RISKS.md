# RISKS — VR-CHAT35M-001

1. The approximately 29 MB model is English-centric with poor factual reliability and no safety tuning. User-visible output must be labelled experimental. It is not suitable for decision/medical/safety/security guidance.
2. GGUF weight size != memory footprint or IPA growth; runtime/native libraries/tokenizer/KV cache/metal require additional resources.
3. Critical integration blocker: `project.yml` excludes LlamaInferenceEngine.swift and LlamaLocalTextModelRuntime.swift (plus model manager/catalog). Current Core runtime falls back to VeilTalk Lite. DO NOT claim the 30 MB model already runs.
4. Re-enabling llama globally could alter the existing AI factory and cause accidental capability escalation, regression, build breaks or large bundle changes. Opt-in isolated adapter only.
5. The current LingCore `AgentCoordinator.send` routes user text through toolExecutor before generation; using its existing AgentChatView would violate chat-only intent. A new isolated screen must bypass it completely.
6. Model source and GGUF revision/sha256 not pinned here. Must verify license, precise artifact byte count, tokenizer and source provenance before embedding.
7. No model weights or opaque binaries in Inbox by AGENTS.md. No Asset Drop grant for this lane.
8. Scope overlaps other Language/Agent projects and latent llama integration. Governor must arbitrate, not auto-merge.
9. Only additive proposed files in patch. No live product mutation, no release, no CI/XCTest performed.

## 2026-11-08 provenance update
Owner file successfully obtained; exact local SHA and metadata in MODEL_PROVENANCE.md. Original point 6 (no local digest) is superseded, but **publisher-side digest validation and trust in source remain pending**. Adapter/runtime are source-only and may not compile against the pinned llama.cpp version until native Xcode checks run. Artifact is not in git, nor available automatically inside an IPA.
