# I9 — A10 Ultra Ω Runtime Isolation Hardening

Status remains `A9 PRIMARY / A10 Ultra Ω SHADOW_ACCELERATOR` with `PRODUCTION_CUTOVER = DENIED`.

I9 fixes measurement-isolation defects found after I8:

- A10 HostContext no longer contains A9 Compute Plan outputs.
- Signal digest is based on raw host facts + raw health input, not prior A9 budget.
- Ultra persistence and pending pairing reset at every runtime-mode boundary.
- A10-only LAB exits immediately to A9 after Ultra internal failure.
- Host SQLite P0 or critical thermal state forces LAB exit after the Ultra sample is recorded.
- Exiting LAB does not replay a stale pre-LAB A9 plan; the next fresh A9 sample is authoritative.
- Dual-mode energy proxy covers A9 + Ultra CPU time; telemetry declares the scope.
- Game runtime context comes from the real local game context (`IDLE` / `ACTIVE`).

No A10 mutation authority is granted.
