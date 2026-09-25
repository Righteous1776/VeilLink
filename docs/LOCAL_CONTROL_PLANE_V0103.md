# VeilLink Local Control Plane — V0.10.3 R5

R5 separates **understanding** from **execution**.

- VeilTalk Lite, a future Qwen runtime, or another local agent may propose a `VeilAppControlCommand`.
- `VeilAppControlPolicy` decides whether the command is read-only, navigation, local mutation, or game mutation.
- `AppModel.executeAppControl(_:)` is the single Core execution entrypoint.
- The execution layer owns BLE, database health, cache/runtime lifecycle, navigation, selected safe settings, and game suggestion execution.
- Every execution is written to the existing privacy-filtered diagnostic log without recording the user's raw prompt.

## R5 control surface

Read-only:
- whole-app status
- A9 status
- agent status
- current game status
- control help

Reversible local actions:
- refresh/start/stop VeilLink BLE service
- run SQLite integrity check
- trim transient caches/runtime memory
- restore automatic performance policy
- activate/unload local agent runtime
- enable/disable visual context
- enable/disable received-image auto-save
- navigate to chats / nearby / games / agent / settings

Separately gated game action:
- execute the latest still-legal suggested move

## Explicitly outside R5

No control command exists for deleting databases, deleting identities, exporting private/session keys, bypassing app lock, arbitrary message sending, hidden owner-mode escalation, or controlling another device.

The Experimental AI history preserved by R4 remains untouched. R5 adds a shared control bus; it does not delete or rewrite the historical MaleCNS/VFLY/Qwen/llama assets.
