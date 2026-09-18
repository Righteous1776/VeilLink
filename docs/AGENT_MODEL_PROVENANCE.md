# Agent Model / Data Provenance

## V0.8.0 shipped assets

No external LLM model and no MaleCNS graph data are shipped in this checkpoint.

The only language runtime is `veillink.foundation.mock.v1`, an internal deterministic source fixture with zero external model bytes. It exists solely to validate local streaming, cancellation and lifecycle behavior and must not be marketed as a language model.

## Locked research inputs (not shipped)

### fly.ai
- Upstream: `alextitonis/fly.ai`
- Pinned commit: `85498d520bf2b6598456dd471c4887290b483b55`
- License: MIT
- Status: research/build recipe reference only.

### MaleCNS
- Dataset: MaleCNS v1.0 / `male-cns:v1.0`
- Source: `https://male-cns.janelia.org/download/`
- License/attribution: CC-BY; engineering contract requires CC BY 4.0 handling for derived shipped artifacts.
- Status: not downloaded into the iOS app and not committed to Git.

### Jhongdlp/FlyBrain
- Pinned commit: `ae30e43562ee29c318606ed7641e53f707f3afc5`
- License: MIT
- Status: secondary architecture reference only.

## Future artifact rule

Every real GGUF/VFLY/native model artifact must record exact upstream revision, license, source hash, conversion command, output SHA-256, byte count, model/graph compatibility version and redistribution notes before it is eligible for an IPA.

## V0.9.0 language training pins

### Legacy/A10 research candidate — SmolLM2-135M-Instruct
- Repository: `HuggingFaceTB/SmolLM2-135M-Instruct`
- Revision: `12fd25f77366fa6b3b4b768ec3050bf629380bac`
- License: Apache-2.0
- Primary weight: `model.safetensors`
- SHA-256: `5af571cbf074e6d21a03528d2330792e532ca608f24ac70a143f6b369968ab8c`
- Upstream model card is English-first. This is a performance/research candidate, not an accepted Chinese shipping model.

### Balanced Chinese training candidate — Qwen2.5-0.5B-Instruct
- Repository: `Qwen/Qwen2.5-0.5B-Instruct`
- Revision: `c89bee90d9f811437d9735454613c35b4a3c4dc8`
- License: Apache-2.0
- Primary weight: `model.safetensors`
- SHA-256: `fdf756fa7fcbe7404d5c60e26bff1a0c8b8aa1f72ced49e7dd0210fe288fb7fe`
- Status: QLoRA training candidate. No claim of iPhone 7 viability until quantized physical-device measurement.

### VeilLink game-policy bootstrap
- Artifact ID: `veillink.game-policy.ranker.v4`
- Source: project-generated deterministic self-play over exact VeilLink Gomoku/Xiangqi/Ludo legal-action adapters.
- Corpus: 900 games / 283,121 candidate rows / 80,385 decisions.
- Corpus SHA-256: `885a5ab8037a2190ac35444b2cedcdba58a0a492839211c889486346af4ab784`.
- 三国兵棋 / `tactical`: excluded.
- Objective: game-balanced listwise candidate ranking with macro Top-1 model selection.
- Model SHA-256: `221193e79f04e06f0fc8c6a6fbfaa8519e203cafd1819aa1ce6048a350dbd9a5`.
- Held-out overall Top-1: 0.845589; macro Top-1: 0.806349.
- This artifact imitates the current bootstrap teacher. It is not expert play and is not MaleCNS.
- Shipping inference export: `VLPOL1`, 848,728 bytes, SHA-256 `9b37decd138c98ea8ff43815d07af0076112be123d1de0b173bde59abf927bbd`.
- Exporter: `Tools/AgentTraining/export_policy_vlpol.py`; source checkpoint SHA-256 `221193e79f04e06f0fc8c6a6fbfaa8519e203cafd1819aa1ce6048a350dbd9a5`.
- The app-side scorer is read-only and can score only engine-generated legal candidates. It does not create a game seat and does not support `tactical`.

## MaleCNS / VFLY1 graph provenance (V0.9.3)

- Authoritative dataset: MaleCNS v1.0 (`male-cns:v1.0`), CC BY 4.0.
- Primary implementation reference: `alextitonis/fly.ai@1dc982f62da58a29f920fdd4d645fcab4da23624`, MIT.
- Pinned fly.ai prebuilt source hashes: `brain.npz cc9bd1ecd00bd703a6fa648bc6ad145c93c7c1ee53debdcc9ce0d1f4305e6aca`; `weights.npz c29919aa44069a271b1ee978abe05fa9bf6e45e4ba3e436e92b624ef1b5be40c`.
- Reference validation counts: 166,700 retained neurons / 25,582,938 directed connections.
- Conversion: `Tools/VeilFlyBuilder/export_vfly.py`; VFLY1 stores source-neuron adjacency, float32 signed normalized weights, stable sensory/readout groups and payload SHA-256.
- Core/Lite derivation: deterministic sensory-forward + readout-reverse graph-guided induced subgraph; every policy parameter is serialized in VFLY metadata.
- Attribution: any redistributed VFLY artifact derived from MaleCNS must retain MaleCNS attribution and CC BY 4.0 terms.
- Scientific qualification: VeilFly runs a simplified LIF computational model over biological connectivity; it must not be described as an exact biological fly brain.
