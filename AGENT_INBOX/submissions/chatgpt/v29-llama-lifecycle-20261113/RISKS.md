# Risks / review boundaries

- This candidate modifies native llama resource lifetime, a sensitive host feature even though only VeilLink/Agent/Language files are proposed. It is INBOX_ONLY. No hardware/Apple compilation or crash proof yet.
- Swift actor reentrancy permits source-level overlap across await; the guard mitigates it. This does NOT prove that the observed signal11 was caused by native shutdown or trim, because MetricKit offsets are unsymbolicated.
- The actor `shutdown()` becomes async. All observed callers already use `await`, but every other hidden consumer must be audited during integration. The deferral can take until the next cooperative cancellation check (normally Task.yield or onPiece), so observe nonresponsive native decode and potential waiting under stress.
- Old runtime cancellation used to mark state ready immediately; the new state remains generating until actual unwind. User-facing state transitions and retry behavior must be verified. Duplicate `prepare()` during an old canceled load returns a safe unavailable error rather than silently launching a second backend.
- `llama_backend_init()/llama_backend_free()` are process-global in native llama and can be shared by multiple independent engine instances. This patch fences per-engine operations only. Governor should separately inspect whole-process reference counting if two instances can load concurrently.
- PR #192 diagnostics fix is independently staged, does not overlap direct files. Issue #185 BLE remains open. Flag/UI change is separate; do not conflate root-cause claims.
- Binary native model and dSYM artifacts must never be uploaded to public Inbox. No forced model access or private logs included.

## Additional lifecycle review risk
Swift Task cancellation does not necessarily stop a destructor already awaiting native generation. The second-pass patch now chains all `shutdownTask` values and uses a generation marker to prevent actor reentrancy from dropping a newer shutdown barrier. This deliberately prioritizes safe release ordering over immediate reloading; if a native generation hangs indefinitely, a subsequent model load may remain blocked. Profiling and a bounded, non-destructive failure UI are needed; never impose a timeout that frees live native pointers.
