# D1A blockers / risks
1. Functional limitation: no PDF/ZIP/audio/movie peer sending, no file bubble; source proves current WireChatContent supports only text/image/voice. This is explicit partial mitigation.
2. PR overlaps #129 (staging lifecycle), #138 (ChatView/image optimization), #139 (ChatView scroll). Governor must apply with order and review, not overwrite independent agent code.
3. File picker broad [.item] still selects executables, but staged content is extension-whitelisted to small UTF8 text or validated image. Executable is not interpreted/executed.
4. Image path still has PR #129's lease-directory cleanup pending. D1A does not duplicate or overwrite that patch.
5. Sync provider false-positive, iCloud coordination timeout, original source alias path, and UIImage preparation compatibility untested in Apple runtime.
6. The actual cross-device binary file transport would change protected wire/attachment validation contracts: separate explicit Governor decision and compatibility testing required.
7. Full D2 and D3 owner clarification remains pending; Batch E five-queue experiment likewise remains conditional.
