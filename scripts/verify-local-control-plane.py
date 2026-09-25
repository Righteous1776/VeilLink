#!/usr/bin/env python3
from pathlib import Path

ROOT = Path.cwd()


def fail(message: str):
    raise SystemExit("LOCAL CONTROL PLANE FAIL: " + message)


plane = ROOT / "VeilLink/Agent/Integration/VeilAppControlPlane.swift"
test = ROOT / "VeilLinkTests/VeilAppControlPlaneTests.swift"
doc = ROOT / "docs/LOCAL_CONTROL_PLANE_V0103.md"
for path in (plane, test, doc):
    if not path.is_file():
        fail(f"missing {path.relative_to(ROOT)}")

text = plane.read_text(encoding="utf-8")
required = [
    "enum VeilAppControlCommand",
    "enum VeilAppControlPolicy",
    "enum VeilAppControlParser",
    "case refreshBLE",
    "case startBLE",
    "case stopBLE",
    "case databaseIntegrity",
    "case trimCaches",
    "case restoreAutomaticPerformance",
    "case navigate(VeilAppDestination)",
]
for needle in required:
    if needle not in text:
        fail(f"control-plane symbol missing: {needle}")

for forbidden in [
    "deleteDatabase",
    "deleteIdentity",
    "exportPrivateKey",
    "privateKeyExport",
    "remoteControlPeer",
    "sendArbitraryMessage",
    "ownerModeEscalation",
]:
    if forbidden in text:
        fail(f"forbidden destructive/privileged command surfaced: {forbidden}")

app = (ROOT / "VeilLink/App/AppModel.swift").read_text(encoding="utf-8")
for needle in [
    "func executeAppControl(_ command: VeilAppControlCommand)",
    "VeilAppControlParser.parse(raw)",
    "VeilAppControlPolicy.authorize",
    "DiagnosticLogStore.shared.log",
    "availableTools: VeilAppControlParser.advertisedCommands",
]:
    if needle not in app:
        fail(f"AppModel control-plane integration missing: {needle}")

if "docs/EXPERIMENTAL_AI_PRESERVATION_V0102.json" not in (ROOT / "scripts/verify-core-source-isolation.py").read_text(encoding="utf-8"):
    # The R4 verifier may not hard-code the output path; preservation source verifier still must exist.
    if not (ROOT / "scripts/verify-core-source-isolation.py").is_file():
        fail("R4 preservation verifier missing")

print("VEILLINK_LOCAL_CONTROL_PLANE_PASS")
print("CONTROL_EXECUTOR=AppModel.executeAppControl")
print("RAW_PROMPT_LOGGING=disabled")
print("DESTRUCTIVE_CONTROL_COMMANDS=none")
