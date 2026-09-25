# VeilLink Auto Regulation — V0.10.5 R7

R7 adds a bounded automatic diagnostics and self-regulation layer on top of Control Plane V3.

## Modes

- `off`: no automatic evaluation action.
- `advisory`: continuously evaluates the same policy but only publishes/logs recommendations.
- `safeAutomatic`: may execute only the reversible allow-list below.

The default after R7 migration is **safeAutomatic**.

## Automatic safe allow-list

The automatic regulator may only:

1. switch the app-local resource focus (`automatic`, `communications`, `agent`, `game`)
2. trim transient caches / local runtime memory
3. refresh VeilLink BLE discovery/link recovery

It cannot automatically stop/start BLE, export diagnostics, change permissions, run database mutations,
execute a game move, navigate UI, send a message, delete data, access/export keys, or control another device.

## Inputs

The policy evaluates:

- iOS thermal state and Low Power Mode
- A9 health score
- BLE pending bytes, control-packet backlog, stall time and recovery count
- current resource focus
- current visible app area and whether Agent/game work is active
- recent automatic mutation / maintenance / BLE-repair timestamps
- a 90-second manual-focus hold after a human/Agent explicit focus command

## Anti-oscillation

- minimum mutation cooldown: 15 s
- cache-maintenance cooldown: 60 s
- BLE-repair cooldown: 20 s
- communications-focus hysteresis keeps the focus until backlog falls below a lower exit threshold
- an explicit manual resource focus is protected for 90 s, except critical/serious thermal protection

## History

Before replacing R6 active control files, the installer copies the R6 control plane, tests, verifier,
documentation and key integration files into `docs/history/control-plane/V0104_R6/` with SHA-256 hashes.
No R1–R6 history or Experimental AI history is deleted or moved.
