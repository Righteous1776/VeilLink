# Scope & risks
- Brightness event coalescing may omit transient intermediate luminance changes. Full system state continues to be available every 30 seconds and via explicit incidents.
- 459→7 is offline filtering against one owner archive. Performance and watchdog improvement unproven.
- The observer still creates a short @MainActor Task per UIScreen brightness notification, but expensive system snapshot/disk capacity sampling only occurs after gate. No user-facing color/brightness behavior changed.
- Real main-thread stalls include many games.lobby events. Could be from multiple workloads; PR #137 logging and #145 SQLite startup proposal still pending.
- MetricKit historical watchdog SIGKILL and CPU exception events do not by themselves identify a single Swift method.
- No product tree, main, workflow dispatch, release or IPA change. All live code changes remain inside PATCH.diff until Governor live lane grant.
