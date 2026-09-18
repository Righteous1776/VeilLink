# Agent Performance Matrix

V0.9.0 adds local camera/Vision, device-only speech policy and external training carriers. No
real LLM or MaleCNS on-device performance claim is made until macOS/iPhoneOS and physical-device
benchmarks exist.

| Profile | Foundation policy | Real-model status |
| --- | --- | --- |
| SE1 / A9 | legacy, short transcript, unload on background/memory pressure | not benchmarked |
| iPhone 7 / A10 | legacy, short transcript, unload on background/memory pressure | physical-device proof required |
| SE2 / A13 | balanced, retain light runtime cache | not benchmarked |
| iPhone 13 Pro / A15 | high, larger future budgets | not benchmarked |
| iPad Air 4 | balanced until dedicated UI/runtime measurements | not benchmarked |

## V0.9.0 local training evidence

- Game ranker training ran in the current CPU-only engineering environment; this validates the
  data/training path, not the requested final GPU campaign.
- The current `veillink.game-policy.ranker.v4` artifact was trained from a deterministic 900-game / 283,121-row corpus and
  reached held-out teacher-agreement Top-1 0.84559 / MRR 0.90602; macro Top-1 is 0.80635.
- 三国兵棋 / `tactical` is excluded from every current training registry and dataset.
- The v4 ranker is exported to a bundled 848,728-byte `VLPOL1` artifact. PyTorch/Swift reference
  scores match to ~1e-6 on the validation fixture. Linux host-only Swift measurements were about
  30.9 ms / 225 Gomoku candidates, 6.0 ms / 44 Xiangqi candidates, and 0.2 ms / one Ludo candidate.
  These numbers are not iPhone 7 measurements.
- Language QLoRA remains a GPU gate. Synthetic domain SFT data is project-owned and reproducible,
  but no Qwen/SmolLM fine-tune is claimed in this environment.
- Camera/Vision and Speech must be profiled on physical iOS devices; Linux parse checks do not
  prove camera thermals, microphone behavior or on-device Mandarin recognition availability.

## Phase-2 measurements required

For each candidate text runtime/model: load time, resident-memory delta, first-token latency, tokens/sec, tested context, 64-token thermal observation, cancel latency and unload recovery.

For later MaleCNS tiers: graph load time/memory, steps/sec, simulated episode wall time, active-spike density, per-decision latency and repeated-decision thermal behavior.

Simulator/Linux results must never be used to claim real iPhone 7 viability.

## V0.9.3 VFLY1 / MaleCNS graph-import status

- VFLY1 builder, verifier, graph-guided Core/Lite extractor, Swift loader and VeilFly native-runtime bridge are implemented.
- Routine LocalLab uses a tiny deterministic VFLY1 fixture and proves: payload hash -> Swift loader -> named sensory group -> native C episode -> named readout.
- The current engineering container has **not** executed the 166,700-neuron / 25,582,938-edge reference graph because the pinned 260 MB prebuilt release assets are not available to this container's network path. Do not convert fixture results into a full-MaleCNS performance claim.
- `MaleCNSReference.vfly` is a build/research artifact, not a phone-shipping target. `VeilFlyCore.vfly` and `VeilFlyLite.vfly` are candidates only after the manually dispatched heavy workflow creates them and physical iPhone measurements validate load time, resident memory, steps/sec, per-decision latency and thermals.
- The first VFLY native validation runtime deliberately disables stochastic noise so graph/encoder/readout determinism can be verified. Matching fly.ai's stochastic reference traces is a separate validation gate.
