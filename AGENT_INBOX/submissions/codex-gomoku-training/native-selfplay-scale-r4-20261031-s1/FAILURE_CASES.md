# Failure cases / quarantine record

## Training data

- Existing 2,000 bundle: 0 invalid games after independent replay.
- S0 10-game smoke: 0 invalid or unfinished games.
- S1 1,000-game shard: 0 invalid or unfinished games.
- Bagua tournament: both 200-game legs independently replayed with 0 invalid games.

## Candidate rejection

Current Bagua preference is rejected for default promotion: 49.75% score, Wilson lower 95% bound 44.88%. This is a valid negative result, not a hidden failure. The raw loss cases remain in the external hashed exports for counterplay analysis.

## Environment incident

An initially incomplete local clone was detected before use and removed; a fresh remote PR #114 checkout supplied the actual compilation source. A concurrent tournament launch failed before either container started because two unused Swift images filled the runtime partition. No game file was created or counted from that failed attempt. The unused `swift:6.2-jammy` image was then removed, preserving the locked `swift:6.2.1-jammy` image; both tournament legs subsequently completed serially.

## Deliberate non-actions

- No Python engine generated moves.
- No model weights, screenshots, ZIP, binary, player record or IPA entered Inbox.
- No App import, schema mutation, default-engine change, main merge or workflow dispatch occurred.
