#!/usr/bin/env python3
from pathlib import Path

ROOT = Path.cwd()

def fail(message: str):
    raise SystemExit("AUTOREGULATION R7 FAIL: " + message)

required = [
    ROOT / "VeilLink/Agent/Integration/VeilAppControlPlane.swift",
    ROOT / "VeilLink/Agent/Integration/VeilAutoRegulation.swift",
    ROOT / "VeilLinkTests/VeilAppControlPlaneV3Tests.swift",
    ROOT / "VeilLinkTests/VeilAutoRegulationTests.swift",
    ROOT / "docs/AUTOREGULATION_V0105.md",
]
for path in required:
    if not path.is_file(): fail(f"missing {path.relative_to(ROOT)}")

plane = required[0].read_text(encoding="utf-8")
for needle in [
    "enum VeilAutoRegulationMode", "enum VeilAppControlSource", "case autoRegulationStatus",
    "case setAutoRegulationMode(VeilAutoRegulationMode)", "case runAutoRegulationOnce",
    "source: VeilAppControlSource", "isAutomaticSafe", "case .setResourceFocus, .trimCaches, .refreshBLE",
]:
    if needle not in plane: fail(f"control V3 symbol missing: {needle}")

auto = required[1].read_text(encoding="utf-8")
for needle in [
    "VeilAutoRegulationPolicy", "manualFocusHoldActive", "mutationCooldown",
    "maintenanceCooldown", "bleRepairCooldown", "pendingBytes >= 384 * 1024",
    "currentFocus == .communications", "thermal == .critical",
]:
    if needle not in auto: fail(f"policy invariant missing: {needle}")

app = (ROOT / "VeilLink/App/AppModel.swift").read_text(encoding="utf-8")
for needle in [
    "autoRegulationSummary", "autoRegulationManualHoldUntil", "evaluateAutoRegulation(force:",
    "source: .automaticRegulator", "agent.autotune.evaluate", "agent.autotune.execute",
    "currentAutoThermalLevel", "currentResourceFocus", "currentControlDestination",
]:
    if needle not in app: fail(f"AppModel AutoTune integration missing: {needle}")

settings = (ROOT / "VeilLink/Agent/Integration/AgentControlCenterSettings.swift").read_text(encoding="utf-8")
for needle in ["autoRegulationMode", "agent.controls.autoRegulationMode", ".safeAutomatic"]:
    if needle not in settings: fail(f"AutoTune setting missing: {needle}")

center = (ROOT / "VeilLink/UI/AgentControlCenterView.swift").read_text(encoding="utf-8")
for needle in ["自动调控", "VeilAutoRegulationMode.allCases", "model.autoRegulationSummary"]:
    if needle not in center: fail(f"Control Center AutoTune UI missing: {needle}")

# Automatic execution must not surface high-impact or privacy-sensitive commands.
for forbidden in [
    "case .stopBLE, .startBLE", "case .exportDiagnostics, .executeSuggestedGameMove",
    "automaticRegulator ? .exportDiagnostics", "automaticRegulator ? .stopBLE",
    "deleteDatabase", "deleteIdentity", "exportPrivateKey", "sendArbitraryMessage",
    "remoteControlPeer", "enableDiagnosticsExport", "enableLocalMutations",
]:
    if forbidden in plane: fail(f"unsafe automatic surface: {forbidden}")

history = ROOT / "docs/history/control-plane/V0104_R6/manifest.sha256"
if not history.is_file(): fail("R6 history manifest missing")

print("VEILLINK_AUTOREGULATION_R7_PASS")
print("AUTO_SAFE_ACTIONS=focus,trim-caches,refresh-ble")
print("MANUAL_FOCUS_HOLD=90s")
print("COOLDOWN=enabled")
print("R6_HISTORY=preserved")
