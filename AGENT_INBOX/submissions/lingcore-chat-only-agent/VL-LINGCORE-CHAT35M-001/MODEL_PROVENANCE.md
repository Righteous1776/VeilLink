# MODEL_PROVENANCE — Verified owner-provided GGUF (2026-11-08)

## Source and provenance
- Source context: owner explicitly selected an existing file in their connected Google Drive; connector search and exact metadata/fetch verified the complete raw file.
- Original filename: `Vertex-0.6-35M-Instruct-Q4_K_M.gguf`
- Size: **29,203,168 bytes** (Google metadata AND downloaded file stat agree)
- File SHA-256 **computed locally from the complete downloaded bytes**:
  `c55c3c32740d5a283c505fc9f9b7313e4b3f0c98bb11efd21b651651d5cb36b5`
- Magic: `GGUF`; format version: **3**
- Tensor count: **112**; metadata key count: **41**
- Internal `general.name`: `Vertex 0.6 35M Instruct`
- Internal `general.architecture`: `qwen3`
- Internal `general.license`: `apache-2.0`
- Internal `general.languages`: `en`
- Internal `qwen3.block_count`: **10**
- Internal `qwen3.context_length`: **1024**
- Internal `qwen3.embedding_length`: **384**
- Internal `tokenizer.ggml.tokens`: **32,002**
- Internal `tokenizer.chat_template`: ChatML with assistant generation prompt

## Provenance limits
These facts were obtained from the owner's file, not through an independent byte-for-byte comparison with the publisher's release. **Publisher-side SHA verification remains pending.** The current bytes can be pinned to prevent accidental local replacements, but pinning does not prove independent upstream authenticity.

No weight files, Drive IDs, private URLs, links with authentication tokens, or retrieved binary bytes are committed to this public repository. The owner remains responsible for keeping the actual GGUF in an approved local app input path or for supplying it through a separately authorized asset distribution workflow.

## Safe integration implications
1. A `Vertex35MModelIntegrityGate` has been staged as source-only, with size, GGUFv3 and exact SHA gates; it re-hashes on each load and cannot blindly reuse `LocalModelManager`'s URL-only cache.
2. `Vertex35MChatRuntime` is staged as an OPTIONAL `#if canImport(llama)` adapter calling the existing dormant `LlamaInferenceEngine`. It rejects non-nil local/visual privileged contexts, bounds output to <=96 tokens, and uses only ChatML messages.
3. Neither file has been applied to product sources. Current project.yml excludes llama sources and no linked iOS module has been demonstrated. Runtime and UI remain unintegrated, and no native inference was executed.
