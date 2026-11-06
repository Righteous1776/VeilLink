# Validation gates — Adaptive Image Compression
- [x] Candidate patch produced against ccafebab147e069fbabfff579dbf323b0d54f191, two exact files only.
- [ ] git apply --check against latest main; swift/clang Apple SDK build and XCTest on macOS: NOT_RUN.
- [ ] Unit test: adaptive quality starts at 0.86, only degrades above target, monotonic, no more than 3 passes/resolution, minimum quality 0.62, zero budget safe.
- [ ] Corpus: camera HEIC/JPEG 12/24/48MP; RAW/DNG; low-light/noisy photos; text screenshot, PNG with transparency, panoramic, portrait, EXIF rotation, zero-byte/corrupt/giant metadata.
- [ ] Validate output <=3 MB and safe MIME, orientation, rendering/cropping/alpha behavior, and no unintentional GPS leakage from transcoded images. Preserve original passthrough behavior explicitly.
- [ ] Performance: 30+ sample median/p95 encoding time and CPU/memory peak against baseline same device; compare true end-to-end transfer over BLE vs LAN, with BLE and Wi-Fi coexistence active.
- [ ] Preempt/cancel during long encode, app background/foreground, low-memory devices, no UI freezes.
- [ ] Governor conflict check with #138 `MediaTransferPolicyTests`; no double-insert tests or change of protocol limits.
