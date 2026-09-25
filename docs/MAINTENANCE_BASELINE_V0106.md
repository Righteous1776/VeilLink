# VeilLink V0.10.6 — Maintenance Baseline R8

R8 is a **feature-freeze maintenance release**. It adds no product capability.

Maintenance work:

- transactional local installer with byte-for-byte rollback on failure;
- fixes diagnostics-export authorization reason ordering;
- fixes `/autotune now` mutation accounting so a no-op is not reported as a mutation;
- deduplicates repeated AutoTune evaluation logs;
- reduces periodic A9/AutoTune polling on legacy A10 devices from 4 s to 8 s, balanced devices to 6 s, high tier remains 4 s;
- archives the active R7 integration before modifying it;
- adds a reusable health report and maintenance invariant test;
- keeps all R5/R6/R7 and Experimental AI history intact.

No GitHub push, branch, Actions dispatch, remote upload, model deletion, history deletion, message deletion, identity deletion, or key export is performed.

Apply after a **fully installed V0.10.5 R7** from the project root:

```bash
python3 apply_v0106_maintenance_r8.py
```

Then run:

```bash
python3 scripts/verify-maintenance-r8.py
python3 scripts/maintenance-health-report.py
```

A full Xcode/iOS build remains a separate validation step on macOS/Xcode.
