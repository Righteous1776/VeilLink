# Owner input audit — independently replayed

Status: read-only audit of two uploaded snapshots, not proof of deployed training or governance acceptance. Repository baseline: `eb487a1901c0ffddfb38b80b9fb56f6d7d749ba0`. No B/C machine gate PASS is claimed; corresponding files are absent from this main snapshot.

## Source integrity

| Input basename | Bytes | SHA-256 | Native payload FNV-1a64 |
| --- | ---: | --- | --- |
| `1-VeilLink-GomokuLearning-20261113-172016-404-27774F62.vltrain.json` | 401296 | `d5cf13940bbb84dc937783700aa129303c4ec1d54a781992099675c3e6325d8b` | `93dcccb56c4ec952` — matched |
| `2-VeilLink-GomokuLearning-20261113-181938-942-EB7990D0.vltrain.json` | 287584 | `050f5abbac2c3f7991db5dbcad4b4d1bd33f49eb1aeeacb5025b17d0696ce325` | `a9737700c7cd421f` — matched |

Native export uses Swift JSONEncoder `.sortedKeys` and compact JSON for the payload, then FNV-1a64 with offset 14695981039346656037 and prime 1099511628211 modulo 2^64. This audit extracted the original payload object and removed whitespace only outside JSON strings, preserving encoder key ordering and exact numeric lexemes; both checksums match. Python `json.dumps(sort_keys=True)` changes numeric-key ordering and floating-point representation and is not an equivalent canonicalizer. This verifies original exported-byte integrity, not independent authenticity of game outcomes.

## Counts and legal replay

| Metric | Input 1 | Input 2 | Combined |
| --- | ---: | ---: | ---: |
| Raw recorded games | 107 | 78 | 185 |
| Raw recorded plies | 2190 | 1666 | 3856 |
| Marked completed | 51 | 59 | 110 |
| Marked unfinished | 56 | 19 | 75 |
| AI started | 3 | 15 | 18 |
| Sum of stored position-action counts | 2190 | 1666 | 3856 |

Exact full role/action-sequence deduplication leaves 156 sequences: 97 marked completed and 59 unfinished. Five marked-completed sequences cannot be replayed from an empty board to a terminal result and have inconsistent position-hash coverage, suggesting partial histories after restored games. Exclude these from supervised outcome labels:

- Input 1, 1-based recentGames sequence 12: 4 plies, aiWon; sequence 18: 5 plies, humanWon; sequence 65: 14 plies, aiWon.
- Input 2, sequence 29: 15 plies, humanWon; sequence 33: 26 plies, aiWon.
- Additional unfinished partial fragments: input 1 sequence 11; input 2 sequence 32.

After exclusion and exact sequence deduplication: **92 terminal games**, 56 human wins and 36 AI wins; **2932 plies**, **2444 unique board/side positions**, **2535 unique board/side/action pairs**. D4 rotation/reflection grouping of complete move traces leaves **89 game families**. Replays checked 15x15 bounds, empty target cells, alternating colors, no moves after the first five-in-a-row, and result agreement with the winner's human/AI role. No failures occurred among these 92 games.

The incomplete records are not asserted to be fabricated or corrupt; the available export does not contain enough starting-state information to establish their outcome labels. Across all records, reconstructed-vs-stored position sets differ: input 1 missing 19 / extra 24; input 2 missing 39 / extra 30. Failed per-ply position/action membership occurs only in the seven partial fragments listed above.

## Role and color identity

`h` and `a` encode **human and AI roles**, not black/white colors. LocalAIGameController records human moves with `.host` and AI moves with `.guest` regardless of selected side. A game starting with `a` is a valid AI-as-black game. Replay colors therefore follow ply parity (black/host first), while winner interpretation follows the actual role prefixes.

Source references at the audited baseline:

- `VeilLink/Agent/Games/LocalAIGameController.swift:282` — human learning actor fixed to host.
- `VeilLink/Agent/Games/LocalAIGameController.swift:990` — AI learning actor fixed to guest.
- `VeilLink/Agent/Games/AdaptiveBoardLearning.swift:108` — board hash includes actual board colors and side to move.
- `VeilLink/Agent/Games/AdaptiveBoardLearning.swift:478` — recording and aggregation by position/action.
- `VeilLink/Agent/Games/AdaptiveBoardLearning.swift:580` — export canonicalization and checksum.
- `VeilLink/Core/MiniGames.swift:278` — legal native application; five-or-more wins.

Because a board hash stores physical colors but PositionStat.actor stores the human/AI role, the same board across human-first and AI-first games can aggregate different role meanings. Training should reconstruct explicit side-relative boards rather than treating PositionStat.actor as a color or blindly merging exported aggregate values.

## Existing strength and limits

In the 92 unique terminal games, AI took all 36 available immediate wins and all 82 required unique immediate blocks. Humans missed 10 immediate wins and 13 unique immediate blocks. These are source-game observations, not a held-out skill rating. Simple one-ply puzzle accuracy alone is consequently insufficient evidence of a major ECLIPSE improvement.

Real owner data supplies 92 complete games, not a million games or a million independent positions. Counterfactual legal candidate evaluations may legitimately supply over a million distinct board/action training rows, provided reports name that unit, identify the teacher, deduplicate, and prove actual fit/inference effects. Assign D4 game families to splits before extracting positions, then remove exact side-relative D4 board overlaps from evaluation. Such training remains teacher distillation and requires an end-to-end ECLIPSE arena against the untrained baseline before promotion.

Raw game histories and boards are intentionally omitted from this report.
