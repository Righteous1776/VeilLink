# Mandatory acceptance — pending integration

1. Apply PATCH.diff to exact V29 main@eb487a1 on isolated Governor branch. Inspect four proposed paths. iOS15 simulator build with the packaged llama module; run all host XCTest and `LlamaNativeLifecycleTests`. None run during Inbox preparation.
2. Repeatedly generate/cancel/trim/unload during prefill, onPiece, progress callback, and after Task.yield; prove no two native decode operations overlap. Make sure generation returns cancellation and no deadlocked shutdown continuation.
3. Prepare/unload while LocalModelManager.validate is suspended, and while llama_model_load_from_file is running; confirm obsolete engine is shut down rather than resurrected. Repeated prepare during cancellation should fail safely rather than double-initialize native global backend.
4. Trigger memory warnings while generating; postponed trim must execute once after unwind and never clear active KV. Verify final model state, context budgets, and token output stability.
5. iPhone7 iOS15.8.3 and iPhoneSE2 iOS15.6.1 physical reproducibility: 50 cycles each of generate, cancel, background, foreground, unload and reload; watch for signal11 and peak memory/hangs. Preserve the original data and full diagnostic archives.
6. Symbolicate all nine attributed MetricKit stacks using matching Build66 binaries/dSYM; compare actual crashing function to newly protected callsites. Track any remaining independent crash sites under Issue #191. Long-run stock/game/BLE unaffected.
7. No release or main merge without Governor gates. Device/Apple CI state: NOT_RUN by this submission.
