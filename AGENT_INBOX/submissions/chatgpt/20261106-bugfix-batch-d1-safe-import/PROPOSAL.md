# Batch D1A — implementable safe import precursor
## Verified source facts
- ChatView file picker allows only UTType.image in current main.
- VeilImportedFileAccess.materializeInBackground already coordinates and stages provider URLs in app-owned UUID directories.
- SessionCoordinator queueContent/sendAttachmentStep only sends text/image/voice and rejects arbitrary MIME; DatabaseStore.beginInboundAttachment similarly rejects nonimage/nonvoice.
- Therefore changing picker to [.item] alone would falsely present PDF/ZIP transfer as working.
## Proposed source behavior
1. Select any Files item. Materialize via existing background Files-provider coordination, maintaining security-scope lifetime inside the current API.
2. Detect images via UTType and pass through existing ImageTranscoder/SessionCoordinator.sendImage. Do not bypass Batch B per-route size policy upon later integration.
3. For TXT/MD/JSON/CSV, enforce owned staged file; nonempty strict UTF-8, <=16,384 bytes, no NUL; put contents into editable chat draft. Sending requires existing user button.
4. Reject PDF/ZIP/audio/video/executables clearly, dispose the *owned* lease snapshot; never delete provider URLs. Use PR #129 staging-lifecycle fix for image path cleanup rather than competing modifications.
5. Do not introduce a fake SessionCoordinator.sendFile API or treat nonimage bytes as image/voice.
## Follow-on D1B (separate, protected design gate)
To deliver actual PDF/ZIP/etc as peer attachments: define capability-negotiated v4-compatible file message extension; unknown peer -> reject locally before queue; enforce allowlist, basename normalization, max bytes, checksum, bounded chunks, identity-scoped keys, receiver manifest validation, protected storage, file bubble, user-authorized ShareSheet export, replay/dedup, and failure cleanup. Protocol/SessionCoordinator/DB acceptance + UI need dedicated Governor review. No pretending the original bug ⑨ is fully solved by D1A.
