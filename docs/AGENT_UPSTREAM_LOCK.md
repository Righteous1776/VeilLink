# Agent Upstream Lock

Observed and pinned for VeilLink V0.8.0 foundation on 2026-09-18.

## VeilLink base

- Repository: `Righteous1776/VeilLink`
- Branch: `main`
- Exact base commit: `0d9f54160c05c6ac2d672dda6f056bf831ef546d`
- Release: V0.7.2 Tactical Render & Transport Pipeline
- Exact base tree: `6035ce00d77d03f33b51cc3dfb984f329bf0c222`

No Agent/AI navigation or runtime implementation existed in that base. V0.7.2 tactical-render and BLE queue optimizations are retained.

## Primary MaleCNS code reference — LOCKED

- Repository: `https://github.com/alextitonis/fly.ai`
- Role: **primary implementation/research reference** for connectome build, signed/normalized weights, LIF dynamics, sensory injection, descending/readout groups and frozen-reservoir design.
- Pinned commit refreshed for V0.9.3: `1dc982f62da58a29f920fdd4d645fcab4da23624`
- License: MIT (`LICENSE` in the pinned repository).
- Relevant pinned implementation files:
  - `flybrain/build.py`
  - `flybrain/brain.py`
  - `flybrain/data.py`
  - `flybrain/eyes.py`
  - `flybrain/reservoir.py`

Do not import or depend on the repository's token, wallet, mining, remote-compute marketplace, browser compute, social-world or hosted-service features.

The pinned `build.py` recipe retains neurons with non-empty MaleCNS superclass annotations, signs presynaptic weights negative for GABA/glutamate/histamine predictions, and normalizes each postsynaptic neuron's incoming absolute weights. Any future VeilFly artifact must record if it deviates from that recipe.

## Authoritative dataset — LOCKED

- Dataset: **MaleCNS v1.0**
- Official site: `https://male-cns.janelia.org/`
- Official download: `https://male-cns.janelia.org/download/`
- neuPrint dataset: `male-cns:v1.0`
- Release date reported by the official project page: 2026-06-08.
- License: CC-BY; the engineering contract requires attribution/redistribution handling as CC BY 4.0.

Primary fly.ai source inputs currently include:
- `body-annotations-male-cns-v1.0-minconf-0.5.feather`
- `body-neurotransmitters-male-cns-v1.0.feather`
- `connectome-weights-male-cns-v1.0-minconf-0.5.feather`
- optic-column assignments pinned by upstream build tooling.

Raw MaleCNS tables are build/research inputs only. Do not commit the 1+ GB graph tables into the VeilLink Git repository.

The `166,700 neurons / ~25.6M connections` values are validation values for the pinned fly.ai build policy, not a universal MaleCNS definition. Any changed filter must create a new provenance manifest with source hashes, retention policy and resulting counts.

## Secondary game-integration reference — LOCKED

- Repository: `https://github.com/Jhongdlp/FlyBrain`
- Role: **secondary reference only** for deterministic native game boundaries, compact observation/action structures and separation between game engine and connectome engine.
- Pinned commit observed for this iteration: `ae30e43562ee29c318606ed7641e53f707f3afc5`
- License: MIT.

It is not VeilLink's canonical MaleCNS preprocessing source and must not replace the primary fly.ai/MaleCNS provenance path.

## V0.9.3 graph-import rule

V0.9.3 introduces the VFLY1 builder/loader and graph-guided Lite/Core extraction. The full 166,700-neuron reference asset remains a build-host artifact and is not committed to Git. A VFLY artifact is eligible for device packaging only when source hashes/counts/provenance pass and the target device tier has been physically benchmarked. Protocol 4, VLGM1 v1 and SQLite Schema V8 remain unchanged.
