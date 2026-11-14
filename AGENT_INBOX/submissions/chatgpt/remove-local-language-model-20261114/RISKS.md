# Removal risk and overlap registry

- This is a destructive change **proposed** by the Owner but staged ONLY inside our Inbox. All actual `git rm` steps, product edits and workflow deletion require Integration Governor review and promotion. No model binaries are committed into Inbox.
- Deleting the model/related source from HEAD does not erase the GGUF binary from Git history; **do not rewrite history, force push, or run destructive GC** for this task without a separate explicit authorization.
- The normal `project.yml` already excludes the model. Do not promise 29MB savings on every standard IPA; the size difference applies to the optional native experimental variant and checked-out repo tree after deletion.
- Removing `Vertex35MChatRuntime` and related code will eliminate its independent text-only experiment. Preserve `LingCore` main AgentChatView with `VeilTalkLiteRuntime` so no accidental loss of local status tools and messaging.
- A10 gameplay AI, brain.npz/weights.npz uploaded training sets, MaleCNS and their predictive assets are OUT OF SCOPE.
- Removing workflow `.github/workflows/lingcore-vertex35m-validation.yml` is a **protected path**. Governor must approve that portion explicitly. Never use this lane to change other workflows.
- If a product target, test or script still refers to a removed Swift symbol, integration CI will fail; this is why the deletion is atomic with project cleanup and a model-free compile test.
- PR #194 native LLM lifecycle patch is obsoleted rather than merged. PR #195 proposes a change to the soon-deleted `LingCoreTinyChatView.swift`; handle that overlap explicitly, preserving its unrelated inline flag functionality.
- No iOS Xcode compile or actual phone smoke tests performed here. Do not claim model uninstalled, crashes fixed or IPA generated before Governor integration.
