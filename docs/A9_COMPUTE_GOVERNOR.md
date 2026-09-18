# A9 Compute Governor — VeilLink adaptation

## Why this exists

The original A9 chip has a very small hot-path cost relative to the rest of VeilLink. V0.9.2 reuses its deterministic 144-state output as a compute scheduling signal instead of leaving the lattice as a diagnosis-only surface.

A9 does **not** create FLOPS and is not a hardware accelerator. It improves effective performance by preventing competing local workloads from overcommitting CPU, memory, thermal headroom and BLE service time.

## Inputs

The governor consumes the existing privacy-safe `VeilA9Decision` plus:

- current device compute tier (`legacyA10`, `balanced`, `high`);
- current foreground focus (`idle`, language chat, video chat, game decision, MaleCNS sandbox, media transfer);
- logical processor count.

No message plaintext, media payload, prompt text, identity key, session key or pairing secret enters the governor.

## Outputs

One `VeilA9ComputePlan` contains:

- transport reserve units;
- MaleCNS budget: tier, workers, neural steps, episode milliseconds, rollouts, sample stride;
- language budget: max-new-tokens, recent-message window, keep-warm hint;
- Vision budget: enabled state, frame interval, classification stride, OCR stride;
- game-planner budget: decision milliseconds, search depth, rollouts, candidate batch size;
- optional local bootstrap-training budget.

## Priority order

1. E2EE/BLE control traffic and app responsiveness are preserved first.
2. User-visible local conversation remains available at a small minimum budget.
3. Current foreground workload receives the majority of optional compute.
4. MaleCNS receives the largest budget in `maleCNSSandbox` and a substantial budget in `gameDecision`.
5. Vision and background training are reduced before transport or UI responsiveness are sacrificed.
6. L4/L5 emergency mode suspends MaleCNS and background training.

## MaleCNS boundary

`MaleCNSComputeConsumer` is the stable runtime port. V0.9.2 now includes `MaleCNSNativeKernelRuntime`, an iOS-compilable C/Swift execution kernel with preallocated CSR/state/spike buffers. `VeilA9ComputeGovernor.bindMaleCNSConsumer()` pushes the current budget into a bound runtime immediately and on every later lattice/focus change. The runtime may consume less than its budget, but must not exceed it.

The native kernel runs bounded multi-step episodes in one native call and supports both full-neuron diagnostic counting and a low-memory compact-readout path. `MaleCNSNativeRolloutPool` now consumes A9 `workerCount` + `rolloutCount` by running independent deterministic candidate episodes in parallel; it does **not** split one neural timestep across workers, so worker count does not change a rollout's floating-point accumulation order. Legacy A10 budgets remain single-worker, while stronger profiles may use more workers when A9 health/thermal/link state permits. A9 still does not own graph memory, neural state, game state, transport or secrets. A real MaleCNS VFLY graph artifact is **not yet shipped**, so this is the execution foundation rather than a claim that the full fly connectome already runs on-device.

## Existing live consumers

V0.9.2 already applies the governor to:

- local Agent prompt/context/token budget;
- front-camera Vision frame cadence, classifier cadence and OCR cadence;
- BLE compute reservation under control backlog/queue pressure;
- app lifecycle sampling: A9 is refreshed every four seconds while foregrounded and suspended in background.

The trained Gomoku/Xiangqi/Ludo ranker remains legality-bounded and deterministic. 三国兵棋 remains excluded from training.

The native VeilFly path is covered by a C + Swift differential smoke in `scripts/local-ci-sim.sh`: bounded episode execution, full vs compact overlapping readouts, lazy histogram allocation, deterministic multi-worker rollout caps and suspend behavior must match fixed fixtures under Swift strict concurrency.

## Compatibility

- iOS deployment target remains 15.0.
- iPhone 7 remains first-class.
- Protocol 4 unchanged.
- VLGM1 v1 unchanged.
- SQLite Schema V8 unchanged.
- no cloud scheduler and no peer offload are introduced.
