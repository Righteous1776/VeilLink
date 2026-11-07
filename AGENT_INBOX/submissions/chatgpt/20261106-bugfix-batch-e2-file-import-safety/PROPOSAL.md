# E2A — 安全文件传输的首个依赖补丁

Main currently supports only image and voice `WireChatContent.Kind`, with database MIME restrictions. It is incorrect to use the existing picture send path for ZIP/PDF, or to claim full generic file send after opening Files.

## Source patch
1. `VeilImportedFileAccess`: adds optional hard `maximumBytes` enforced during NSFileCoordinator copy by chunks; oversized source is rejected and app-owned lease cleaned, existing callers unchanged (default nil).
2. `MediaTransferPolicy`: 2 MB prospective initial cap; safe path-component (no slash, backslash, control scalar, >180 UTF8 bytes) validation; proposed file MIME mapping and capability bit 3 = 8.
3. XCTest proposals: verify archive bound, provider original is preserved, name rejection and MIME mapping.

## Required E2B protected integration, NOT in this proposal
- Add a distinct authenticated `WireChatContent.Kind.file`, binding display name in encrypted manifest.
- Extend sender and receiver validation, reassembly, SHA-256/checkpoint and encrypted attachment storage.
- Negotiate signed capability bit 3 in Hello, maintain legacy ACK masks, gate **both enqueue and every actual send** on live peer's bit3. Older app must never see unknown content kind.
- UI generic picker separate from image picker and D1A text-to-draft; message bubble with explicit Save/Share, no auto-opening attachments.
- Tests include malformed MIME, path traversal, DOS sizes, interrupted device transfer, old-to-new coexistence and new-to-old refusal.
- Only after Governor protocol/security authorization, actual Xcode and real two-device verification.

No change to wire version, database schema, identity, key management, or existing image/voice transfer in E2A.
