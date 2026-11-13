# Mandatory acceptance — pending integration

1. Apply PATCH.diff to exact V29 main@eb487a1 on isolated Governor branch. Inspect four proposed paths. iOS15 simulator build with the packaged llama module; run all host XCTest and `LlamaNativeLifecycleTests`. None run during Inbox preparation.
2. Repeatedly generate/cancel/trim/unload during prefill, onPiece, progress callback, and after Task.yield; prove no two native decode operations overlap. Make sure generation returns cancellation and no deadlocked shutdown continuation.
3. Prepare/unload while LocalModelManager.validate is suspended, and while llama_model_load_from_file is running; confirm obsolete engine is shut down rather than resurrected. Repeated prepare during cancellation should fail safely rather than double-initialize native global backend.
4. Trigger memory warnings while generating; postponed trim must execute once after unwind and never clear active KV. Verify final model state, context budgets, and token output stability.
5. iPhone7 iOS15.8.3 and iPhoneSE2 iOS15.6.1 physical reproducibility: 50 cycles each of generate, cancel, background, foreground, unload and reload; watch for signal11 and peak memory/hangs. Preserve the original data and full diagnostic archives.
6. Symbolicate all nine attributed MetricKit stacks using matching Build66 binaries/dSYM; compare actual crashing function to newly protected callsites. Track any remaining independent crash sites under Issue #191. Long-run stock/game/BLE unaffected.
7. No release or main merge without Governor gates. Device/Apple CI state: NOT_RUN by this submission.

## Additional shutdown-order regression
- Repeatedly call unload twice or more while native generation is blocked in a token callback and while a prior shutdown awaits generation unwind. Confirm all older destructors finish **before** a later prepare() calls `llama_backend_init`.
- Start prepare while waiting for the previous shutdown Task; call unload during the wait. Ensure the early `prepare()` receives cancelled and does not clear the newer shutdownTask (verify shutdownGeneration), nor mark state ready.
- Stress alternating unload, cancel, prepare, unload with two independent local chat sessions (if supported by Coordinator); track process-global llama backend initialization/free order and guard against late completion resurrecting an old engine.

## Native process-lease regression additions
- Test `LlamaProcessLoadLeaseTests` for exclusive ownership, second acquire waiting until release, and cancelled waiter cleanup. With two independent `LlamaLocalTextModelRuntime` instances, cancel/unload the first while generating then attempt prepare on the second; the second must not call native backend init until first shutdown completes.
- Repeat `LocalTextModelCoordinator.activateOverride()` and `restoreBaseRuntime()` during active decoding. Confirm no nested llama backend init/free, no double-free, and that cancellation of a waiting acquire eventually releases its entitlement without a leaked permit.
- Explicit consequence: this implements one active native llama backend owner per process. Concurrent independent local models will serialize until an owner unloads; this is a stability tradeoff on 2GB RAM legacy hardware and must be reviewed with product requirements.
