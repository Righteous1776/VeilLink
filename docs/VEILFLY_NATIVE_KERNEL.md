# VeilFly Native Kernel V1

## Purpose

V0.9.2 turns the useful engineering pattern from the original A9 native fast path into a MaleCNS-oriented execution kernel. The Linux/x86 A9 `.so` is **not** copied into the iOS app. Instead, VeilLink ships a small C17-compatible kernel compiled as part of the iOS target.

The retained ideas are:

- contiguous CSR graph arrays;
- caller-owned/preallocated state buffers;
- no heap allocation in the neural hot loop;
- one native episode call for many deterministic timesteps;
- compact native readout reduction instead of exporting the whole neural state;
- deterministic multi-rollout parallelism that consumes A9 worker/rollout budgets without changing one rollout's floating-point order;
- A9 compute budgets clamping episode length, rollout count, worker count and runtime tier.

## Runtime shape

`MaleCNSNativeGraph` validates one outgoing-adjacency CSR graph once at load time. `MaleCNSNativeKernelRuntime` owns voltage, current scratch, external drive, two spike buffers and per-neuron spike counts.

Hot path:

`validated CSR -> active spike adjacency propagation -> fused voltage update + scratch clear -> spike buffer swap`

`runEpisode()` keeps both spike buffers inside native code for the whole episode. The public one-step API remains available for differential tests and research.

## Fused scratch clear

The first prototype cleared `current_scratch` with a full `memset` before every neural step. V1 keeps the public one-step API defensive, but the episode path clears scratch once at episode start and then resets each current slot while the voltage loop already visits that neuron. That removes one full-neuron memory pass from every subsequent episode tick.

## Compact readouts

`MaleCNSNativeReadoutMap` stores both group→neuron membership and an inverted neuron→group CSR. Groups may overlap. Two modes are retained:

- full-count research mode keeps a lazily allocated per-neuron spike histogram and can reduce it after the episode;
- compact decision mode accumulates only selected readout groups inside the native LIF threshold branch and never materializes the full histogram.

The compact path is a **memory optimization**, not a throughput claim. On the current 50k/3.2M-edge synthetic host benchmark it was roughly neutral to slower than the very cache-friendly full-count path. Its reason to exist is that a 166,700-neuron fly.ai-sized graph can avoid a 666,800-byte (~651 KiB) per-neuron `UInt32` histogram during ordinary game/cognitive decisions. `trimComputeState()` releases the full histogram if it was ever requested.

This is intended for descending-neuron / motor / affect readouts after the real VFLY graph loader is introduced.

## A9-governed rollout pool

`MaleCNSNativeRolloutPool` consumes the existing `workerCount` and `rolloutCount` fields from `MaleCNSComputeBudget`. It parallelizes **independent candidate episodes**, not one connectome timestep. Each worker owns private voltage/current/spike state while graph arrays are shared by Swift copy-on-write storage. This preserves the exact per-rollout accumulation order, so 1-worker and 4-worker executions produce identical results for the same requests.

The pool snapshots the current A9 budget at the start of a batch. A later emergency/suspend is observed between candidates; pool ownership of idle workers is dropped immediately, but an in-flight bounded native episode is not mutated from another thread. This avoids data races while keeping emergency latency bounded by one episode.

## A9 binding

`VeilA9ComputeGovernor.bindMaleCNSConsumer()` weakly binds a runtime. The current MaleCNS budget is delivered immediately and after every A9 lattice or foreground-focus change. L4/L5 can therefore suspend the runtime without giving A9 direct access to graph memory or game state.

## Development-host microbenchmarks

These are synthetic Linux x86_64 measurements, **not iPhone or real MaleCNS performance claims**. All compared paths produced identical final voltages/spikes.

- native C episode vs equivalent Swift loop, 50,000 neurons / 3,200,000 edges / 180 steps: `84.681 ms` vs `370.073 ms`, about **4.37×** in that run. This is the main demonstrated gain from moving the hot loop into contiguous native buffers.
- A9 rollout pool, 30,000 neurons / 960,000 edges / 120 steps / 8 independent rollouts: 4 workers delivered a **median ~2.41× throughput improvement** over 1 worker across seven host runs, while result arrays were exactly equal.
- fused scratch clear alone is modest: in a controlled 50,000-neuron / 800,000-edge A/B, the 7-run median was about **1.016×**. It is retained because it removes a redundant full-neuron pass without changing semantics, not because it is the primary accelerator.
- compact readout is intentionally treated as a memory path. In the 50,000-neuron / 3,200,000-edge synthetic test it was not consistently faster than full-count mode, but it avoids allocating the neuron-wide spike histogram in ordinary decision workloads.

Real MaleCNS v1.0 retained graphs have very different edge density and spike density, and iOS thermal scheduling is different from this host. Physical iPhone 7 / iPhone 13 profiling remains mandatory.

## Still deferred

- real VFLY1 graph loading;
- MaleCNS v1.0 Lite/Core graph artifacts;
- reference LIF constants/provenance lock for production simulation;
- deterministic noise/refractory implementation;
- real-device thermal/memory/steps-per-second benchmark;
- multi-rollout worker orchestration using the A9 `workerCount` budget.
