# VeilLink High-Fidelity Image Compression V2 — Preserving quality first

## Current main audit
- Swift ImageIO HEIC/JPEG encodes, and PNG passthrough already exist. Hard per-image wire limit 3,000,000 B; 48 KiB authenticated, encrypted, checkpointed chunks. No recipient capability handshake for AVIF/JXL/WebP currently exists.
- Current JPEG/HEIC passthrough cutoff is only 1,800,000 B despite hard limit 3,000,000 B, causing needless lossy recompression of already-valid 2 MB photos.
- Current quality sweep 0.94 ... 0.66 across six dimensions can lose more quality and expend excessive CPU.
- Large transparent PNG currently may be transcoded into a format that cannot preserve alpha.

## Proposed real code changes
1. Preserve existing JPEG/HEIC unchanged when within 3 MB and <=4096px maximum dimension; eliminates lossy re-encoding and processing for common files.
2. If over the wire cap, prefer HEIC (when encoder available), 0.96 initial quality / 0.86 floor with **three feedback-based encodes per resolution** max and five resolution ceilings. Shrink image resolution only when acceptable quality cannot fit. Already-under-hard-limit candidates are sent immediately; no unnecessary search for 1.8 MB.
3. Oversized PNG is first re-encoded losslessly at permitted dimensions; if it has alpha, downsample with alpha preserved and NEVER silently flatten transparency into JPEG/HEIC. If no permitted PNG fits, return explicit too-large error.
4. Keep native JPEG fallback when HEIC cannot fit or unavailable; no wire/media MIME/protocol/schema changes, no dependency required for baseline.
5. Add XCTest on passthrough decisions, budget guard, minimum quality and bounded attempts.

## Third-party library assessment — source pinned, NOT yet shipped
- **Recommended opt-in high-quality JPEG backend:** [google/jpegli](https://github.com/google/jpegli), pinned commit `031a0077f5799a6041004267fc12b956c1f52a20`, BSD-3-Clause, API is compatible with classic libjpeg, resulting image/jpeg is decodable by legacy JPEG clients.
- Candidate sources `README.md`, `LICENSE`, `CMakeLists.txt`, `lib/jpegli/encode.h` have been fetched/read from GitHub at that commit, but the full library has not been vendored into VeilLink. `FILES/vendor-jpegli-source.sh` is a reproducible opt-in source acquisition script for a Governor-approved integration environment, not an install claim.
- The vendor gate needs iOS arm64 + simulator static library / XCFramework built on Apple SDK, C++ symbols/Swift bridging validation, dependency/SBOM/license & patent notices, benchmarks on iPhone 7/13. No unreviewed binary build or arbitrary GitHub artifact enters the repository.
- Jpegli may improve density and fidelity for JPEG-compatible fallback, but can raise CPU encode latency; native HEIC is preferred where available. JPEG XL lossless would require protected negotiated codec capability before any wire use.

## Relation to existing PRs
This V2 candidate **replaces**, rather than stacks on top of, speed-oriented PR #152's `ImageTranscoder.swift` loop. #138 modifies media size gates, and #152 modifies the same `MediaTransferPolicyTests.swift` class; Governor chooses one codec search path and combines test coverage. Do not edit those agent branches directly.
