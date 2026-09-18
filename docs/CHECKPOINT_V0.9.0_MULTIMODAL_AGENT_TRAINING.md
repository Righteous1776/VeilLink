# V0.9.0 — Multimodal Agent Training Foundation

## Scope

V0.9.0 advances the local Agent foundation without changing Protocol 4, VLGM1 v1, SQLite Schema V8, current BLE semantics, or 三国兵棋 rules. 三国兵棋 is explicitly excluded from all current Agent training datasets.

## Local video conversation

- `AgentVideoChatView` provides front-camera preview and low-frequency local visual context.
- `AgentCameraController` uses device-local Vision requests for face count, image labels and lightweight OCR summaries; raw frames are not sent over BLE and no network upload path is present.
- iPhone 7/A10 uses the lowest sampling cadence and reduced OCR frequency.
- `AgentVoiceController` only accepts speech recognition when `supportsOnDeviceRecognition` is true; there is no automatic cloud fallback.
- Final local speech transcripts may be sent directly to the Agent, and completed replies may be read with local `AVSpeechSynthesizer`.
- Camera/audio/model work remains lazy and stops on view exit/background/lifecycle pressure.

This is intentionally not described as a native multimodal LLM. The visual path is a local key-frame summary feeding the text runtime.

## Game-agent training

Training-enabled games:
- Gomoku
- Xiangqi
- Ludo

Explicitly excluded:
- Tactical / 三国兵棋

The generic game-agent ports expose normalized observations and engine-generated legal candidates. The training exporter cannot select `tactical`. Learned scorers never mutate game state directly and cannot bypass legality validation.

The exporter is seed-reproducible, including Ludo: its deterministic dice stream now derives the
training session identifier from `--seed + episode` rather than a random UUID. The optional slow
training smoke generates the same one-episode shard twice and requires byte-for-byte equality.

The completed V0.9.0 deterministic bootstrap corpus contains 900 self-play games (300 per enabled game), 283,121 candidate rows and 80,385 decision points. The v4 ranker uses stratified validation, inverse-frequency game-balanced sampling and macro Top-1 checkpoint selection. The largest completed local CPU checkpoint was evaluated on the held-out split:

- overall Top-1: 0.8455891501804156
- overall MRR: 0.9060191949149248
- macro Top-1: 0.8063488761829771
- macro MRR: 0.8759616113157311
- Gomoku Top-1: 0.847972972972973
- Xiangqi Top-1: 0.6772836538461539
- Ludo Top-1: 0.8937900017298045

The dataset SHA-256 is `885a5ab8037a2190ac35444b2cedcdba58a0a492839211c889486346af4ab784`; the v4 model SHA-256 is `221193e79f04e06f0fc8c6a6fbfaa8519e203cafd1819aa1ce6048a350dbd9a5`. These scores measure agreement with the current heuristic self-play teacher, not expert strength. The checkpoint is a bootstrap policy artifact, not MaleCNS.

### On-device policy export

The v4 PyTorch checkpoint is exported to `VLPOL1` and bundled as `game_policy_ranker_v4.vlpol` (848,728 bytes, SHA-256 `9b37decd138c98ea8ff43815d07af0076112be123d1de0b173bde59abf927bbd`). `TrainedGamePolicyRuntime` implements the exact inference graph in Swift (`Linear + GELU + LayerNorm`, dropout disabled at inference). A cross-runtime fixture produced PyTorch/Swift scores matching to roughly 1e-6 for Gomoku/Xiangqi/Ludo. The runtime receives only candidates enumerated and validated by the existing game engine; `tactical` remains unsupported. It is a sandbox policy scorer, not a live autonomous game seat.

On the current Linux engineering host, optimized Swift scoring of an initial position measured roughly 30.9 ms for 225 Gomoku candidates, 6.0 ms for 44 Xiangqi candidates and 0.2 ms for one Ludo candidate. These are host measurements only; no iPhone 7 latency claim is made.

## Language training carrier

Pinned research candidates are stored under `Tools/AgentTraining/manifests/language_model_pins.json`.

- Legacy/A10 benchmark candidate: `HuggingFaceTB/SmolLM2-135M-Instruct` pinned to a fixed revision and SHA. It is English-first and must not be represented as a finished Chinese model.
- Primary Chinese QLoRA candidate: `Qwen/Qwen2.5-0.5B-Instruct` pinned to a fixed revision and SHA.
- `train_language_lora.py` refuses training when the pinned base-weight SHA does not match.
- No external LLM weights are committed to Git.
- The repository includes a project-owned synthetic domain SFT dataset generator for offline/privacy/video-chat behavior.

MaleCNS connectivity remains frozen. Future trainable components are stimulus encoders, readouts and planners around the connectome; do not alter the biological graph and call that MaleCNS training.

## Training scalability

- self-play exporter supports per-game shards and append mode;
- game ranker has a listwise objective and GPU-capable PyTorch path;
- existing candidate scorer supports DDP/AMP;
- language QLoRA uses 4-bit loading and gradient checkpointing;
- normal CI uses tiny fixtures and never downloads external model weights.

## Release gates not claimed locally

Linux LocalLab can parse/typecheck the portable surface and run deterministic harnesses. The following still require Work/macOS or physical devices:

- XcodeGen + full Simulator build;
- complete XCTest under Apple frameworks;
- Release `iphoneos` unsigned IPA;
- camera/Vision/Speech behavior on iOS 15;
- real iPhone 7 memory, thermals and on-device speech availability;
- real local LLM inference and quantized runtime benchmark.
