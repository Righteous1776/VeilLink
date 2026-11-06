# V2 risk ledger
- **#152 direct file conflict**: ImageTranscoder.swift and MediaTransferPolicyTests.swift. This proposal intentionally replaces the quality target algorithm; DO NOT combine both loops or duplicate test additions.
- **#138 test overlap**: MediaTransferPolicyTests.swift from Batch B; if selected, Governor must merge test cases separately. No automatic policy budget changes.
- Tradeoff: quality-first may send ~3MB (vs ~1.8MB target), slowing BLE uploads. LAN benefits from no unnecessary encode; route-aware policy needs a separate negotiated, measured gate. Higher local photo fidelity is not free throughput.
- When even high-quality HEIC/JPEG cannot fit 3MB, algorithm downsamples to 1600px; **not lossless**. There is no lossless 20MB->3MB universal guarantee.
- Large alpha-bearing PNG may now reject rather than silently flatten transparent pixels. This is intentional preservation behavior; product UI needs a meaningful 'send original via future file transport' option.
- PNG "lossless" refers to pixel encoding at a chosen resolution; downsampling is NOT pixel-perfect and should be explained in UI.
- Jpegli third-party code NOT installed, no binaries are committed, no claims that iOS library compiles. Sourcing step uses independently reviewed pin and preserves BSD notices. Security and license compliance still require downstream gate.
- No main edits, wire protocol/schema changes, CI workflow, iOS IPA or release; hardware and Xcode tests NOT_RUN.
