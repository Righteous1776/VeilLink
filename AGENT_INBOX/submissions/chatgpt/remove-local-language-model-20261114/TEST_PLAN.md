# Acceptance gates — not executed during Inbox staging

1. On fresh Governor integration branch from main@eb487a1, `git apply --check PATCH.diff`, then apply. Verify exact 29 tracked deletion paths from `DELETE_MANIFEST.txt`; execute `git rm` in same atomic change.
2. `git diff --check` then assert no tracked `*.gguf` language model, no `LlamaInferenceEngine.swift`, no `Vertex35MChatRuntime.swift`, no specialized Vertex build script, no `lingcore-vertex35m-validation.yml`.
3. XcodeGen `project.yml` generate; iOS 15 / simulator Release+Debug builds. Assert `VeilLink.app` contains zero `*.gguf` and does not embed `llama.xcframework`; confirm iPhone7 deployment compatibility.
4. Run new `LocalLanguageModelRemovalTests` and existing `VeilTalkLiteRuntimeTests`, `AgentCoordinator` tests, A9/A10, game AI and connection safety tests. No native language model loading, hashing or downloaded weights.
5. Verify AgentChatView still does lightweight replies and authorized local status queries; verify apps do not show deleted micro-chat navigation entry and main Chat/Photos/Games/Settings/Network continue working.
6. Check existing settings `autoLoadLanguageModel` only invokes model-free runtime and cannot instantiate llama accidentally even if an unrelated `llama` module is available.
7. Cross-test PR #195's surviving inline flag rendering/chat input changes; remove only its now-deleted micro-chat source, not its regular chat/voice work. Ensure unrelated PRs #192 and #201 still apply cleanly.
8. iOS17+/26 smoke plus iPhone7 iOS15.8.3 and SE2 iOS15.6.1 (native build/device tests NOT_RUN). No IPA build/distribution from this Inbox.
9. Optional repository housekeeping AFTER integration: GitHub historical blob remains and requires separate owner-approved history maintenance, not force-push as a side effect of deletion.

## Evidence states
- SOURCE_EVIDENCE: checked exact main git tree; 29 deletion paths all exist; GGUF weight file exactly 29,203,168 bytes.
- PATCH: proposed, not product-applied.
- XCODE_BUILD: NOT_RUN.
- IPHONE_DEVICE_TESTS: NOT_RUN.
- MODEL_DELETED_FROM_MAIN: NO.
