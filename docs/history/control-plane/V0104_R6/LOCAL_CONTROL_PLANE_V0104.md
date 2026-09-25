# VeilLink Local Control Plane V2 — V0.10.4 R6

R6 extends R5 from a command bus into a small app-level operations plane.

## New read-only observability

- transport status: running state, connected/recovering links, pending bytes, control backlog and weakest health
- media status: image transfer caps, preview size, outbound attachment cache budget and auto-save state
- performance status: device performance profile, override state, A9 mode and current scheduler focus
- diagnostics status: recent privacy-filtered event count, local diagnostic disk usage and retention budget

## New reversible control

`VeilAppResourceFocus` exposes four temporary scheduler intents:

- automatic: return to idle/automatic scheduling
- communications: prioritize BLE/media transfer headroom
- agent: prioritize local assistant work
- game: prioritize Native Bot/game planning

These are app-local scheduling hints. They do not alter iOS system Bluetooth, system Low Power Mode, thermal protection or device settings.

## Diagnostics export

Diagnostic export is intentionally a separate `localExport` permission tier.

- ordinary read-only diagnostics stay available
- local mutation permission alone is not enough to export
- `allowDiagnosticsExport` defaults to false
- the AI/control bus cannot enable its own export permission
- export uses the existing privacy-filtered RuntimeDiagnosticsBridge
- the resulting package may contain technical identifiers such as device/app/link identifiers, but not intentionally record chat plaintext, private/session keys, pairing codes or raw AI prompts

## History preservation

Before replacing the R5 control-plane implementation, the R6 installer copies the R5 implementation, tests, verifier and documentation into `docs/history/control-plane/V0103_R5/` and writes a SHA-256 manifest. No Experimental AI history from R4 is deleted or moved.
