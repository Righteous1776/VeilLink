# Reproducibility — S1 native Bot execution

All paths below are external to the repository product tree. `GomokuBot.swift` and `GomokuFormationLearning.swift` are referenced directly from the complete PR #114 checkout; the compatibility shell supplies only Foundation types needed to compile those unchanged files.

```bash
docker run --rm -v /workspace/veillink-gomoku-training-QkowvH:/work -w /work/runner swift:6.2.1-jammy \
  swiftc -O -o gomoku-native Compat.swift \
  /work/remote-source/repo/VeilLink/Agent/Games/GomokuFormationLearning.swift \
  /work/remote-source/repo/VeilLink/Agent/Games/GomokuBot.swift main.swift

docker run --rm -v /workspace/veillink-gomoku-training-QkowvH:/work -w /work swift:6.2.1-jammy \
  /work/runner/gomoku-native --games 1000 --seed 20261031 --start-game 10000 \
  --budget-ms 40 --formation cycle --out /work/output/s1-1000.jsonl

python3 /workspace/veillink-gomoku-training-QkowvH/audit/replay.py \
  /workspace/veillink-gomoku-training-QkowvH/output/s1-1000.jsonl
```

The runner atomically renames each completed shard; it rejects an incomplete game and labels one preset opening separately from every actual Bot decision. The auditor is independent rule code and does not generate moves. Follow-on shards must use a distinct `--start-game` range and remain outside Git.

Bagua export and paired test commands are recorded in `RUN_SHA256SUMS.txt`; the source scripts and hashes are listed there for exact reconstruction.
