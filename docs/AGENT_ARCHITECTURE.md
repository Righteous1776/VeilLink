# VeilLink Local Agent Architecture

## Product boundary

V0.8.0 introduces a reusable local Agent platform and the fourth root section, **灵核**. The internal route is `.agent`; the user-facing name may change without changing the route contract.

The foundation is local-first and offline-first. It does not add cloud APIs, web search, autonomous phone actions, unrestricted file/database access or peer-assisted private inference.

## Current stack

```text
UI
├── 对话
├── 附近
├── 灵核 (.agent)
└── 设置

Agent Foundation
├── AgentCoordinator (@MainActor composition/lifecycle)
├── AgentCapabilityProfile (legacy/balanced/high policy)
├── AgentSession (ephemeral V1 transcript)
├── AgentDiagnostics (privacy-safe counters)
└── Language branch
    ├── LocalTextModelRuntime
    ├── LocalTextModelCoordinator
    ├── AgentPromptAssembler
    ├── AgentTokenStream
    └── MockLocalTextModelRuntime (Phase-1 fixture only)
```

## Hard boundaries

- Agent language runtime does not depend on `TacticalState`.
- Agent foundation has no direct Keychain, BLE transport or unrestricted `DatabaseStore` handle.
- Generated text is presentation data only; it cannot invoke application functions.
- The Phase-1 transcript is ephemeral and does not migrate SQLite Schema V8.
- Opening ordinary chat/nearby/settings does not load the Agent runtime.
- Entering the Agent section prepares the runtime lazily.
- Backgrounding cancels generation. Legacy profiles unload; stronger profiles trim.
- Memory pressure cancels generation and applies the selected capability policy.

## Language runtime contract

`LocalTextModelRuntime` owns prepare/generate/cancel/trim/unload behind one stable interface. V0.8.0 deliberately uses a deterministic local mock so UI, cancellation and lifecycle can be validated before choosing a real native inference backend.

The next phase may replace only the runtime implementation. The UI and AppModel do not call C/C++ inference code directly.

## Future cognitive/game branch

MaleCNS work is deferred until the foundation passes macOS CI and iPhoneOS packaging. The future branch will be separated from the language runtime and from SwiftUI:

```text
AgentGameAdapter observation
 -> MaleCNS stimulus encoder
 -> native MaleCNS runtime
 -> readout/intention vector
 -> planner
 -> legal AgentActionCandidate
 -> game adapter validation
 -> existing encrypted game event path
```

No live tactical game semantics or VLGM payloads are changed in V0.8.0.

## V0.9.0 multimodal/training extension

```text
Agent UI
├── AgentChatView
└── AgentVideoChatView
    ├── AgentCameraController -> local Vision summary -> AgentVisualContext
    └── AgentVoiceController  -> on-device speech text / local TTS

Game training
├── AgentGameAdapter
├── GomokuAgentAdapter
├── XiangqiAgentAdapter
├── LudoAgentAdapter
└── AgentGameRegistry (tactical excluded)

Offline training carrier
├── SelfPlayExporter.swift
├── train_policy.py
├── train_policy_ranker.py
├── build_agent_sft_dataset.py
└── train_language_lora.py
```

Raw video frames are not an Agent text-model contract. The language runtime receives only compact local visual context. Live game mutation remains owned by each game engine; training and future planners receive observations and legal candidates only.
