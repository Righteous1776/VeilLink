# Current checkpoint

V0.3.6 Runtime Optimization, based on V0.3.5 Haptics & Conversation Controls. Protocol 4 and SQLite Schema V8 remain unchanged. This checkpoint focuses on lower CPU/memory/SQLite/UI-refresh overhead without changing feature semantics: cheaper BLE reassembly bookkeeping, throttled stale cleanup, single-statement retry scheduling, quantized attachment UI notifications, conversation-list refresh isolation, and additional V8 lookup indexes.
