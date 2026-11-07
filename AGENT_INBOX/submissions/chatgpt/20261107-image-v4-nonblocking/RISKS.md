# Risks
- 2.9MB BLE image remains potentially slow, especially with shared headset radio; correct choice is user-visible progress and bounded priority, not silent denial.
- Fallback score is a heuristic (at least 22% savings) and not a perceptual fidelity metric; corpus/SSIM and human review required.
- PNG re-encoded at smaller pixel dimensions preserves alpha but is not pixel-identical lossless.
- Only 3MB Wire v4 remains an absolute limit; larger original pictures still need successful compression to fit.
- No Apple SDK/real-device runtime tests; no product/main, IPA, release or workflow changes.
