# R12 arbitration and risk register

- Overlap: Codex fitted-model PR #209 (source frozen), ECLIPSE strategy R10 #207, R11 #210, V9 seven-tier #199, alternate native R5 #193/#196, ECLIPSE UI #204. Do not combine engines, controllers or training pipelines without Governor decision.
- Privacy: only public machine-generated 920 arena records analyzed; no Owner private original game exports copied into Github. Fitted coefficients stay exactly frozen; model hashes recorded.
- Memo hash: 4096 direct-mapped board-fingerprint+side+square keys and full slot identity comparisons prevent ordinary hash-bucket collision errors. A true 64-bit board Zobrist collision is still possible and would affect heuristic ordering. Not a tactical proof cache.
- Nonterminal board invariant: R12 leaf scanner assumes position is valid nonterminal; caller's existing `GomokuState.apply` rule checks are final authority.
- Performance: deeper leaf evaluation may consume more time than it saves and reduce effective search depth. Flags are off by default; only full equal-time A/B can justify enabling.
- Detection: independently verified immediate win and forced block are exact under unrestricted freestyle Gomoku, not Renju forbidden moves. Cannot prove arbitrary VCT or general "human-strategy superiority".
- Evaluation bias: 920 Codex arena games were previously used to evaluate frozen model. Re-analysis of avoidable traps is retrospective diagnostics, not fresh independently held-out strength.
- Runtime: independent small-module Swift6 tests pass; full R5 integrated Xcode not run; no real IPA or build percentage claim.
