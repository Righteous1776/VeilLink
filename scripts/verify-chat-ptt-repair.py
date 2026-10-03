#!/usr/bin/env python3
from pathlib import Path


root = Path(__file__).resolve().parents[1]
conversation = (root / "VeilLink/UI/ConversationViews.swift").read_text(encoding="utf-8")
tool_center = (root / "VeilLink/UI/ToolCenterView.swift").read_text(encoding="utf-8")
session = (root / "VeilLink/Security/SessionCoordinator.swift").read_text(encoding="utf-8")
ptt_wire = (root / "VeilLink/Voice/PTTWire.swift").read_text(encoding="utf-8")
app_model = (root / "VeilLink/App/AppModel.swift").read_text(encoding="utf-8")

# The existing assistant sheet must remain reachable from a live ChatView menu.
for token in (
    "@State private var showsAgentAssistant = false",
    'Button { showsAgentAssistant = true } label:',
    'Label("灵核助手", systemImage: "sparkles")',
    ".sheet(isPresented: $showsAgentAssistant)",
    "AgentConversationAssistantSheet(model: model, conversation: conversation, messages: messages)",
):
    if token not in conversation:
        raise SystemExit(f"FAIL assistant entry is not reachable: {token}")

if 'Text("G.711 µ-law · 8 kHz · 40 ms")' not in tool_center:
    raise SystemExit("FAIL PTT frame-duration copy is not 40 ms")
if 'Text("G.711 µ-law · 8 kHz · 80 ms")' in tool_center:
    raise SystemExit("FAIL stale 80 ms PTT frame-duration copy remains")

if "let priority = VeilPTTTransportPolicy.priority(for: packet.kind)" not in session:
    raise SystemExit("FAIL PTT control sender bypasses the ordering policy")
if "transportSend?(transportID, envelope, priority)" not in session:
    raise SystemExit("FAIL PTT control sender does not apply the ordering policy")
for token in ("case .begin:", "return .control", "case .end:", "return .realtime"):
    if token not in ptt_wire:
        raise SystemExit(f"FAIL PTT ordering policy is incomplete: {token}")

for token in (
    "let walkieTalkie: VeilWalkieTalkieAudioController",
    "sessions.onPTTControl = { [weak walkieTalkie]",
    "sessions.onPTTAudioFrame = { [weak walkieTalkie]",
):
    if token not in app_model:
        raise SystemExit(f"FAIL PTT receive is still page-dependent: {token}")
if "model.sessions.onPTTControl = nil" in tool_center:
    raise SystemExit("FAIL leaving the walkie-talkie page disables PTT receive")

print("VEILLINK_CHAT_PTT_REPAIR_PASS")
