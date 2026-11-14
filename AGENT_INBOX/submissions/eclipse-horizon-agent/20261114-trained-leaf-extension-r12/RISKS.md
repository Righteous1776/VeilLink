# R12 operational/research risks and overlaps

- **Unintegrated dependency**: Codex PR #209 trains and executes a 48-tree ordering model but is still only an INBOX proposal. R12 `PATCH.diff` is an overlay on that kernel, not a patch directly applicable to V29 main. Do not represent this drop as active app strength.
- **Overlap**: native R5 proposals #193/#196, V9 seven-tier #199, ECLIPSE strategy R10 #207, R11 counter-fork #210 and R9 UI #204. Governor must select one engine/ordering source and arbitrate duplicated gates. No self-merge.
- **Speed**: leaf inspection visits up to 572 five-cell windows, multiple forced blocks can extend leaf nodes. Isolated classifier ~6µs per random board on Linux host; full 5,000-node PVS could use substantial time and complete fewer main depths. Do not claim performance gain or playing strength without equal-time arena results.
- **Limited proof**: two distinct opponent five-completions with no own immediate win is a proof of short loss on freestyle rules. A unique forced block is NOT a winning or losing proof. No all-purpose VCT, Renju forbidden moves, or guaranteed human strategy inference.
- **Training/validation leakage**: 920 Codex generated assessment games are used for regression/audit only; they cannot be reported as independent after selecting this algorithm or as new training rows. The 1,848,616 records are candidate actions, not 1.8m games or distinct boards.
- **Rollback**: `r12HorizonQuiescence=false` by default preserves frozen Codex semantics. Any future per-tier activation requires Gov + arena+device tests. Limits never multiply full V9 2x/4x/6x time.
- **Privacy**: private tactical PV/candidate squares cannot appear as live player hints; ECLIPSE R9 telemetry firewall applies.
- **Legal/governance**: no model weights, binary archives, Apple builds, background execution, signing, release, protected storage/protocol changes.
