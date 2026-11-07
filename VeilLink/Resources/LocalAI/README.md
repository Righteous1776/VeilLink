# Vertex 35M — owner-approved binary exception

This directory stores **exactly one** pinned model file. Unlike the normal repository policy, the owner explicitly allowed this ~29 MB GGUF to enter a dedicated integration branch.

- Upstream: https://huggingface.co/VertexResearch/Vertex-0.6-35M-Instruct-GGUF
- Exact filename: Vertex-0.6-35M-Instruct-Q4_K_M.gguf
- Expected byte count: 29,203,168
- SHA-256: c55c3c32740d5a283c505fc9f9b7313e4b3f0c98bb11efd21b651651d5cb36b5
- GGUF format version: 3
- Model: 35M Qwen3-family, Q4_K_M
- Upstream license: Apache-2.0
- Verification input: exact user-provided Drive copy, independently read and locally hashed; upstream SHA cross-check remains pending
- Import: isolated GitHub Actions job downloaded upstream and verified this digest before committing binary
- Source-of-truth restriction: **not** in Agent Inbox, no other GGUF model included
- Standard project.yml: model excluded; no default app size or behavior changes
- Optional native project: generate via scripts/prepare-vertex35m-ios.sh (requires macOS/Xcode)
- Capability: text generation only; no tools, app context, BLE, database, game mutations, A9/A10/A13 controls or authority
- Validation: static source and hash checks precede native simulator tests. Never treat a green hash check as proof of generation quality.
