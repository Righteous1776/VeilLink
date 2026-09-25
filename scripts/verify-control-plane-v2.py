#!/usr/bin/env python3
from pathlib import Path

ROOT = Path.cwd()

def fail(message: str):
    raise SystemExit("CONTROL PLANE V2 FAIL: " + message)

plane = ROOT / "VeilLink/Agent/Integration/VeilAppControlPlane.swift"
test = ROOT / "VeilLinkTests/VeilAppControlPlaneV2Tests.swift"
doc = ROOT / "docs/LOCAL_CONTROL_PLANE_V0104.md"
for path in (plane, test, doc):
    if not path.is_file():
        fail(f"missing {path.relative_to(ROOT)}")

text = plane.read_text(encoding="utf-8")
required = [
    "enum VeilAppResourceFocus",
    "case transportStatus",
    "case mediaStatus",
    "case performanceStatus",
    "case diagnosticsStatus",
    "case exportDiagnostics",
    "case setResourceFocus(VeilAppResourceFocus)",
    "case localExport",
    "diagnosticsExportEnabled",
]
for needle in required:
    if needle not in text:
        fail(f"missing V2 symbol: {needle}")

for forbidden in [
    "deleteDatabase", "deleteIdentity", "exportPrivateKey", "privateKeyExport",
    "remoteControlPeer", "sendArbitraryMessage", "ownerModeEscalation",
    "enableDiagnosticsExport", "enableLocalMutations",
]:
    if forbidden in text:
        fail(f"forbidden command surfaced: {forbidden}")

settings = (ROOT / "VeilLink/Agent/Integration/AgentControlCenterSettings.swift").read_text(encoding="utf-8")
for needle in [
    "allowDiagnosticsExport",
    'agent.controls.allowDiagnosticsExport',
    "allowDiagnosticsExport = false",
]:
    if needle not in settings:
        fail(f"diagnostics export gate missing: {needle}")

app = (ROOT / "VeilLink/App/AppModel.swift").read_text(encoding="utf-8")
for needle in [
    "exportedDiagnosticsURL",
    "case .transportStatus:",
    "case .mediaStatus:",
    "case .performanceStatus:",
    "case .diagnosticsStatus:",
    "case .setResourceFocus(let focus):",
    "case .exportDiagnostics:",
    "RuntimeDiagnosticsBridge.shared.exportBundle",
    "diagnosticsExportEnabled: agentControls.allowDiagnosticsExport",
]:
    if needle not in app:
        fail(f"AppModel V2 integration missing: {needle}")

home = (ROOT / "VeilLink/UI/AgentHomeView.swift").read_text(encoding="utf-8")
if "model.exportedDiagnosticsURL" not in home or "ShareSheet(items: [url])" not in home:
    fail("diagnostics export share sheet missing")

history = ROOT / "docs/history/control-plane/V0103_R5/manifest.sha256"
if not history.is_file():
    fail("R5 control-plane history manifest missing")

print("VEILLINK_CONTROL_PLANE_V2_PASS")
print("OBSERVABILITY=transport,media,performance,diagnostics")
print("RESOURCE_FOCUS=automatic,communications,agent,game")
print("DIAGNOSTICS_EXPORT=independently-gated")
print("R5_HISTORY=preserved")
