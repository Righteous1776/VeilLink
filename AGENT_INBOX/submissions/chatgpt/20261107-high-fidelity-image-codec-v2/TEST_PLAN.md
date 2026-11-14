# V2 gates
- [x] Source files retrieved from main ccafebab147e069fbabfff579dbf323b0d54f191; original text matched; unified diff round-trip reconstructed expected bytes.
- [x] Pure Swift 6.2.1/Linux policy math: 8/8 local assertions PASS (pass-through, limits, feedback floor and no needless recompression).
- [ ] macOS Xcode build, XCTest in VeilLinkTests, iOS 15 deployment check, code-signing: NOT_RUN.
- [ ] Compression corpus: 12/24/48 MP photos, original HEIC/JPEG 2.9 MB passthrough, 10MB noisy JPEG, RAW/DNG, gradient sunset, human skin tone, small text screenshot, transparent PNG, metadata/color profile, portrait rotation; expect MIME and orientation correct.
- [ ] Image quality: no bit-level change on passthrough; compare PSNR/SSIMULACRA2 or equivalent vs original only at same dimensions, human blind rating for reduced images. Never state 'lossless' for lossy HEIC/JPEG.
- [ ] Validate 3MB wire cap, 4096px maximum original passthrough, bounded 3 attempts each resolution, cancellability, no file import UI regression.
- [ ] Transport: LAN and BLE exact same encodings, compare total end-to-end time including local encoder (not just compressed byte sizes).
- [ ] Third party: acquire jpegli pinned sha on macOS, license check, full SDK C++ build + Swift bridging, test high-fidelity JPEG output in old clients; performance rollback if CPU latency grows.
- [ ] Arbitration #152 and #138 before promotion to main.
