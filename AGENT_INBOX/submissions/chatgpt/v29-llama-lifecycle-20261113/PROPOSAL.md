# V29 P0 native llama lifecycle risk mitigation

## Evidence
The two Owner V29.0 Build66 black boxes were re-examined locally. All 9 MetricKit signal11 crash diagnostics (6 payloads on iPhone7, 3 on SE2; not necessarily 9 independent crashes) mark an attributed thread containing a call chain `llama -> VeilLink -> libswift_Concurrency.dylib`. The exact faulting function is NOT symbolicated. Do not expose original backtraces, binary UUIDs or device IDs publicly.

## Verified source-level hazard
`LlamaInferenceEngine` is a Swift actor, but `generate()` suspends repeatedly (`Task.yield()`, `onPiece`, `onProgress`) while retaining raw llama model/context/sampler and batch pointers. Swift actor reentrancy permits another `generate`, `trim` or `shutdown` call to access/free/reset the very same C pointers while the first generation is paused. This is a concrete potential use-after-free/invalid-state hazard; a plausible but NOT proven cause of the observed BadAccess.

`LlamaLocalTextModelRuntime.cancel()` previously marked `.generating` as `.ready` before the cancelled native call unwound, allowing new requests. `prepare()` could resume after `unload()` and resurrect an already-cancelled engine.

## Proposed fix (advisory patch only)
1. Pure `LlamaNativeLifecycle` policy: only one native generation may begin; trim is deferred until generation exits; shutdown dominates trim.
2. Engine `generate` acquires lifecycle in-flight guard BEFORE capturing raw pointers, releases it through a `defer` on success/error/cancellation. Shut down only after all raw-pointer work stops.
3. Engine `shutdown() async` cancels via generation gate, queues checked continuations while generation runs, frees pointers once when generation unwinds, then resumes shutdown waiters. `prepare` cannot proceed with a new backend until the actual shutdown task finishes. No new lock held across llama decode.
4. Engine `trim` never resets native KV cache/sampler midway through decode; postponed request applies upon generation completion.
5. Runtime `cancel()` no longer falsely publishes `.ready` while decode is active. Runtime `prepare()` checks cancellation epochs across both await boundaries; if a newly loaded native engine is obsolete, unload it asynchronously before returning without overwriting the newer state. An in-progress preparation blocks duplicate native initialization.
6. New isolated state-machine tests for no duplicate generation, deferred trim, shutdown priority, and idle release.

## Not changed
No model weights, quantization, inference hyperparameters, prompt templates, Wire4, BLE, secure session, game Engine/AI/Net, DB schema, signing, ACK gate, or Astra assets. No main source edits, merge, IPA, or CI dispatch.

## Evidentiary limits
Real crash disappearance requires exact Build66 dSYM + new IPA UUID and repeated iPhone7/SE2 inference-cancel/unload tests. This patch is not evidence that every signal11 fault has been fixed.
