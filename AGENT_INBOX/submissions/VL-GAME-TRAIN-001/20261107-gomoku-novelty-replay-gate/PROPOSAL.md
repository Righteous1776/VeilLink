# Evidence-based learning overhaul, bounded Phase R1

The owner supplied three original V28 `.vltrain.json` archives (Gomoku human, Xiangqi human, Gomoku native self-play). Offline Swift Foundation JSONSerialization canonical FNV1a checksum matches all three. Actual Gomoku native games: 5,141 finished/legally replayable, but only **276 unique full action sequences**, 12,042 unique positions. This is real bot-vs-bot execution evidence, not 5,141 distinct training experiences. Xiangqi original: 8 games, 371 unique positions; not enough to prove a new high-ELO policy. Personal Gomoku: 81 records; 3 result markers not reconstructible from complete move arrays, so avoid trusting them as terminal labels.

**Patch** (not applied):
1. Expand Gomoku offline self-play initial openings from 17 handpicked choices to deterministic central 7x7 = 49 legal candidates.
2. Validate each proposed native completed game by replaying every move with `GomokuState`, checking exact FNV position hash/current turn, legal stone, terminal and winner/draw claim. Never reward forged or partial games.
3. Deduplicate exact action histories *before recording* new native games. Keep old archive untouched; no destructive repair of the original 5,141 samples.
4. Add XCTest coverage for opening uniqueness, nonterminal forgery rejection and same-match replay rejection.

**Important:** New experimental C++ generated sparring games and tactical position labels remain separate shadow assets for downloadable offline review only. This PR contains NO user gameplay JSON, NNUE weights, binaries or shadow curriculum and does NOT claim production chess strength improvement.

**Why these gates matter:** blindly adding repeat wins/losses can amplify biases in existing bounded move-ranking preferences. Novelty, legal replay, corpus provenance and real native A/B tournament must precede production promotion.
