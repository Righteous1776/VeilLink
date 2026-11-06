# Risks and overlaps
- **Overlap #138**: new tests added to MediaTransferPolicyTests.swift, also modified by Codex Batch B; combine tests explicitly after arbitration. The actual ImageTranscoder.swift encoding change is independent of #138 transport caps.
- Quality 0.62 is lower than old minimum 0.66, so some noisy photos may degrade more; the algorithm prioritizes speed/transport size. No blind claim of equal quality; image corpus comparison required.
- Higher-resolution photos may need several (up to 3 x 5 x 2=30) encodes if HEIC cannot fit and JPEG fallback is needed; fastest-case one encode. Original 42 x 2 worst-case removed, no empirical latency claim.
- HEIC compression may be unsupported on some devices; retain fallback JPEG while original JPEG/PNG passthrough remains unchanged.
- PNG with transparency >3 MB may be converted to a lossy format as on existing main; requires dedicated alpha-aware preserve pipeline if needed.
- `Task.checkCancellation()` works at iteration boundaries, not during an ImageIO encoder call itself. Cancel latency remains bounded by a single encode time.
- Reducing repeated attempts may increase payload sizes for some content and harm slow BLE transfer time; must measure end-to-end before promoting. #138 route-specific budgets can help.
- No main edits, no wire schema/codec addition, no CI release, no signing/IPA. Apple SDK + device tests NOT_RUN.
