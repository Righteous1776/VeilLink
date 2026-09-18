# VeilLink Agent Training

Offline/reproducible training carrier for VeilLink Agent work.

## Hard scope

- training-enabled games: Gomoku, Xiangqi, Ludo;
- `tactical` / 三国兵棋 is explicitly excluded until its redesign is approved;
- legal actions always come from the exact VeilLink rule engines;
- learned scores never bypass game legality validation;
- MaleCNS connectivity itself is frozen: trainable components are encoders/readouts/planners around it, not the biological edge table.

## Game self-play

`SelfPlayExporter.swift` supports per-game shards, deterministic episode offsets and append mode so long campaigns do not depend on one huge process:

```bash
./selfplay_exporter --output g0.jsonl --games gomoku --episodes 100 --episode-offset 0 --seed 1776
./selfplay_exporter --output g1.jsonl --games gomoku --episodes 100 --episode-offset 100 --seed 1777
./selfplay_exporter --output l0.jsonl --games ludo --episodes 100 --episode-offset 0 --seed 3776
```

Rows contain a 256-float state vector, 16-float candidate vector, stable state hash and teacher label. For identical arguments, exports are byte-reproducible: JSON keys are sorted and Ludo's deterministic dice session is derived from `seed + episode`, not a random UUID. Episode offsets keep `(game, episode, ply)` unique after concatenating shards. `train_policy.py` remains the binary bootstrap; `train_policy_ranker.py` is preferred because it optimizes candidate ordering per decision and reports Top-1/MRR rather than class-imbalanced accuracy.

## Language domain SFT

`build_agent_sft_dataset.py` generates project-owned domain rows for offline/privacy/video-chat behavior without copying third-party chat text. It deliberately excludes 三国兵棋.

Pinned research candidates live in `manifests/language_model_pins.json`. No model weights are committed to Git.

`train_language_lora.py` is GPU-only by design. It SHA-verifies the pinned Hugging Face base weight before QLoRA, uses a fixed revision, and enables gradient checkpointing. Run it on a GPU host; CPU smoke training must not be reported as the final local-language-model campaign.
