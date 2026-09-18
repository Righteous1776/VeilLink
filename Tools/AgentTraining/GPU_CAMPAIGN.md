# GPU Campaign — VeilLink Agent

This file describes the next large-compute run. It is a carrier, not evidence that the connected ChatGPT container has a GPU.

## 1. Game policy

Generate independent shards by game and seed. Keep `tactical` absent.

```bash
./selfplay_exporter --output g0.jsonl --games gomoku --episodes 5000 --episode-offset 0 --seed 1776
./selfplay_exporter --output x0.jsonl --games xiangqi --episodes 5000 --episode-offset 0 --seed 2776
./selfplay_exporter --output l0.jsonl --games ludo --episodes 5000 --episode-offset 0 --seed 3776
cat g0.jsonl x0.jsonl l0.jsonl > all.jsonl
```

Train multiple seeds. `train_policy.py` supports DDP/AMP. The v4 listwise ranker is the preferred objective: use game-balanced sampling and macro Top-1 selection so high-volume Ludo decisions cannot hide Xiangqi regressions. When scaling to multi-GPU, keep decisions intact when sharding so a candidate set never spans ranks.

Do not evaluate with binary row accuracy alone. Minimum reports: held-out decision Top-1, MRR, per-game metrics, random-candidate baseline, model SHA and dataset SHA.

## 2. Language QLoRA

The current Chinese candidate is pinned in `manifests/language_model_pins.json`. Build project-owned domain data:

```bash
python build_agent_sft_dataset.py --out agent_sft.jsonl --rows 6000 --seed 1776
python train_language_lora.py \
  --base-model Qwen/Qwen2.5-0.5B-Instruct \
  --revision c89bee90d9f811437d9735454613c35b4a3c4dc8 \
  --expected-weight-sha256 fdf756fa7fcbe7404d5c60e26bff1a0c8b8aa1f72ced49e7dd0210fe288fb7fe \
  --data agent_sft.jsonl --out qwen-veillink-lora
```

Use held-out Chinese dialogue/video-context prompts. Do not merge and ship until the quantized native runtime is benchmarked on iOS 15 and real iPhone 7 hardware.

## 3. MaleCNS

Do **not** fine-tune or rewrite the MaleCNS connectivity graph. Train/fit only the surrounding encoder, readout or planner after the VFLY/reference runtime exists. Record graph version + encoder version + readout version + seed for deterministic game work.
