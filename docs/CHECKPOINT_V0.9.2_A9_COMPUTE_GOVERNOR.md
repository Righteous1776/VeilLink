# V0.9.2 — A9 Compute Governor

## Scope

Promote the V0.9.1 A9 lattice from health-only advisory output into a deterministic resource scheduler for local Agent workloads while preserving the original privacy/security/game boundaries.

## Delivered

- `VeilA9ComputePlanner`: pure deterministic scheduler driven by A9 decision + device tier + foreground focus.
- `VeilA9ComputeGovernor`: observable local plan owner.
- `MaleCNSComputeBudget` and `MaleCNSComputeConsumer`: stable native-runtime budget port.
- `MaleCNSNativeKernelRuntime` + `VeilFlyKernel.c`: allocation-stable CSR/LIF execution foundation.
- native bounded episode runner: many neural timesteps per call, A9-clamped by `neuralStepBudget`.
- fused episode scratch clear: removes one full-neuron clear pass from each subsequent tick.
- compact overlapping native readout mode for descending/readout groups, with the full per-neuron histogram lazily allocated only for research/diagnostics.
- deterministic `MaleCNSNativeRolloutPool`: A9 `workerCount` / `rolloutCount` now drive independent parallel candidate episodes without changing per-rollout floating-point order.
- live A9 -> MaleCNS consumer binding; emergency budgets suspend new rollout work and release idle worker ownership without asynchronously mutating in-flight state.
- dynamic local-language token/context budget.
- dynamic Vision sampling/classification/OCR cadence.
- BLE transport reserve under control backlog or queue pressure.
- game-planner and optional training budget contracts.
- four-second foreground A9 resampling; background sampling stops.
- Settings/Agent diagnostics expose current compute mode and MaleCNS tier.
- Linux C/Swift native differential smoke verifies episode propagation + readout; macOS/iPhoneOS remains the release gate.

## Safety / determinism

- A9 does not manufacture compute; it schedules existing headroom.
- no raw prompts/media/keys enter A9.
- no AI action bypasses game legality.
- emergency mode suspends MaleCNS and bootstrap training before user-critical paths.
- current trained policy still excludes 三国兵棋.

## Compatibility

Protocol 4, VLGM1 v1, SQLite Schema V8 and iOS 15 target are unchanged.

## Native-kernel status

A real MaleCNS/VFLY graph is not yet bundled. The native kernel has been validated with deterministic synthetic fixtures and host microbenchmarks only. On the current development host the C hot loop showed ~4.37× over an equivalent Swift loop in one heavy synthetic run, and 4-worker independent rollout evaluation showed ~2.41× median throughput over 1 worker across seven synthetic runs. These are **not** iPhone claims. Real iPhone 7/iPhone 13 performance, thermal behavior and MaleCNS trace equivalence remain future gates. See `docs/VEILFLY_NATIVE_KERNEL.md`.
